# PostgreSQL の UPDATE 更新行有無のサイズ変化確認

■ 動機  
理解が曖昧だったため、UPDATE 時の追記振る舞いを確認しました。  
いくつか学びが得られました。

---

- 少量更新で更新対象行がない場合、UPDATE を投げてもリレーショナルデータのファイルサイズが増えることはない
- 大量更新を行う場合、更新対象行がないか事前に抽出した方が良い
- 大量更新を行う場合、ロールバックしてもファイルサイズが増えることがある

※更新対象がない UPDATE を投げる時点でアプリケーションの設計に問題があるとは思う

---

■ 実験環境

- Windows 10
- PostgreSQL 14

■ 実験内容

- 1.以下のデータベースをリストアします。  
  https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/

```psql
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE dvdrental TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
pg_restore -U postgres -d dvdrental ./dvdrental.tar
```

- 2.更新対象のテーブルサイズを取得します。

```psql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='rental';"
  byte
---------
 1228800
(1 行)
```

- 3.更新対象行ありのデータ更新を行います。

```psql
DO $$
DECLARE
num constant int := 1000;
BEGIN
  FOR a IN 1..num LOOP
     UPDATE rental SET staff_id = 1 WHERE rental_id = 1;
  END LOOP;
END$$;
```

- 4.更新対象のテーブルサイズを取得します。

```psql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='rental';"
  byte
---------
 1302528
(1 行)
```

- 5.更新対象行なしのデータ更新を行います。

```psql
DO $$
DECLARE
num constant int := 1000;
BEGIN
  FOR a IN 1..num LOOP
     UPDATE rental SET staff_id = 1 WHERE rental_id = -1; --存在しないrental_id
  END LOOP;
END$$;
```

- 6.更新対象のテーブルサイズを取得します。
  サイズは増えていません。

```psql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='rental';"
  byte
---------
 1302528
(1 行)
```

- 7.更新対象行あり　かつ　ロールバック

```psql
DO $$
DECLARE
num constant int := 1000;
BEGIN
  FOR a IN 1..num LOOP
     UPDATE rental SET staff_id = 1 WHERE rental_id = 1;
	 if a = 500 then
	 	raise exception 'ロールバック';
	 end if;
  END LOOP;
END$$;
```

- 8.更新対象のテーブルサイズを取得します。  
  サイズが増えています。  
  ・・・いやいや、postgres はそんな馬鹿じゃないはず。
  更新量やワーカーメモリ何かの設定が作用している可能性がある。

```psql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='rental';"
  byte
---------
 1335296
(1 行)
```

- 9.更新量を減らします。

```psql
DO $$
DECLARE
num constant int := 100; -- 更新回数を100に減らした
BEGIN
  FOR a IN 1..num LOOP
     UPDATE rental SET staff_id = 1 WHERE rental_id = 1;
	 if a = 50 then
	 	raise exception 'ロールバック';
	 end if;
  END LOOP;
END$$;
```

- 10.更新対象のテーブルサイズを取得します。
  サイズは増えていません。更新データサイズが大きくメモリに保持できなかった場合は、ディスクに吐き出していそうです。

```psql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='rental';"
  byte
---------
 1335296
(1 行)
```

- 11.次に組み込みトリガ関数 suppress_redundant_updates_trigger を試します。

```psql
CREATE TRIGGER z_min_update
BEFORE UPDATE ON rental
FOR EACH ROW EXECUTE PROCEDURE suppress_redundant_updates_trigger();
```

- 12.更新対象ありの UPDATE を行います。

```psql
DO $$
DECLARE
num constant int := 10000;
BEGIN
  FOR a IN 1..num LOOP
     UPDATE rental SET staff_id = 1 WHERE rental_id = 1;
  END LOOP;
END$$;
```

- 13.更新対象のテーブルサイズを取得します。 サイズは増えていません。更新対象があっても、データに差異がなければ UPDATE しないようです。

```psql
psql -U postgres -d dvdrental -c "analyze;"

psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='rental';"
  byte
---------
 1335296
(1 行)
```

以上

