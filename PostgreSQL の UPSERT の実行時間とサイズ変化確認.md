# PostgreSQL の UPSERT の実行時間とサイズ変化確認

■ 結果

| ケース                | 速度            | サイズ         |
| --------------------- | --------------- | -------------- |
| INSERT→UPDATE(投捨て) | 9 秒 674 ミリ秒 | 1056768 byte   |
| UPDATE→INSERT(投捨て) | 6 秒 987 ミリ秒 | 532480 byte    |
| UPSERT(INSERT 時)     | 311 ミリ秒      | 532480 byte    |
| UPSERT(UPDATE 時)     | 499 ミリ秒      | 524288 byte    |
| INSERT                | 203 ミリ秒      | 532480 byte    |
| UPDATE                | 474 ミリ秒      | 524288 byte    |
| INSERT(トリガ)        | 301 ミリ秒      | 532480 byte    |
| UPDATE(トリガ)        | 1 秒 989 ミリ秒 | 1,040,384 byte |

---

■ 実験環境

- Windows 10
- PostgreSQL 14  
  ※組み込みトリガ関数 suppress_redundant_updates_trigger は今回使用しません

---

- 1.以下のデータベースをリストアします。  
  https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/

```sql
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE dvdrental TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
pg_restore -U postgres -d dvdrental ./dvdrental.tar
```

- 2.更新対象のテーブルサイズを取得します。

```sql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
 byte
------
 8192
(1 行)
```

- 3.INSERT→UPDATE の実行

```sql
DO $$
DECLARE
num constant int := 11000;
BEGIN
  RAISE NOTICE 'START %',clock_timestamp();
  FOR a IN 1000..num LOOP
  	 INSERT INTO country (country_id, country) values (a, a::text);
     UPDATE country SET country = a::text WHERE country_id = a;
  END LOOP;
  RAISE NOTICE 'END %',clock_timestamp();
END$$;

NOTICE:  START 2022-11-14 21:43:14.088348+09
NOTICE:  END 2022-11-14 21:43:23.732776+09
DO

クエリが 9 秒 674 ミリ秒 で成功しました。
```

- 4.サイズの測定

```sql
psql -U postgres -d dvdrental -c "analyze;"
ユーザー postgres のパスワード:
ANALYZE

psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
ユーザー postgres のパスワード:
  byte
---------
 1056768
(1 行)
```

- 5.一度、DB をドロップして、再度 restore します。

* 6.UPDATE→INSERT の実行

```sql
DO $$
DECLARE
num constant int := 11000;
BEGIN
  RAISE NOTICE 'START %',clock_timestamp();
  FOR a IN 1000..num LOOP
  	 UPDATE country SET country = a::text WHERE country_id = a;
  	 INSERT INTO country (country_id, country) values (a, a::text);
  END LOOP;
  RAISE NOTICE 'END %',clock_timestamp();
END$$;
NOTICE:  START 2022-11-14 21:51:37.81709+09
NOTICE:  END 2022-11-14 21:51:44.776673+09
DO

クエリが 6 秒 987 ミリ秒 で成功しました。
```

- 7.サイズの測定

```sql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
ユーザー postgres のパスワード:
  byte
--------
 532480
```

- 8.一度、DB をドロップして、再度 restore します。

- 9.UPSERT 実行

```sql
DO $$
DECLARE
num constant int := 11000;
BEGIN
  RAISE NOTICE 'START %',clock_timestamp();
  FOR a IN 1000..num LOOP
  	 insert into country (country_id, country) values (a, a::text)
	 on conflict (country_id)
	 do update set country = a::text;
  END LOOP;
  RAISE NOTICE 'END %',clock_timestamp();
END$$;
NOTICE:  START 2022-11-14 22:32:09.149531+09
NOTICE:  END 2022-11-14 22:32:09.438205+09
DO

クエリが 311 ミリ秒 で成功しました。
```

- 10.サイズの測定

```sql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
ユーザー postgres のパスワード:
  byte
--------
 532480
```

- 11.一度、DB をドロップして、再度 restore します。

* 12.INSERT のみ

```sql
DO $$
DECLARE
num constant int := 11000;
BEGIN
  RAISE NOTICE 'START %',clock_timestamp();
  FOR a IN 1000..num LOOP
  	 INSERT INTO country (country_id, country) values (a, a::text);
  END LOOP;
  RAISE NOTICE 'END %',clock_timestamp();
END$$;

NOTICE:  START 2022-11-15 06:17:08.695045+09
NOTICE:  END 2022-11-15 06:17:08.829217+09
DO

クエリが 203 ミリ秒 で成功しました。
```

- 12.サイズの測定

```sql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
ユーザー postgres のパスワード:
  byte
--------
 532480
```

- 13.前回データを残し、更新対象行がある状態で UPDATE のみ実行

```sql
DO $$
DECLARE
num constant int := 11000;
BEGIN
 RAISE NOTICE 'START %',clock_timestamp();
 FOR a IN 1000..num LOOP
    UPDATE country SET country = a::text WHERE country_id = a;
 END LOOP;
 RAISE NOTICE 'END %',clock_timestamp();
END$$;

NOTICE:  START 2022-11-15 06:25:01.047929+09
NOTICE:  END 2022-11-15 06:25:01.502172+09
DO

クエリが 474 ミリ秒 で成功しました。
```

- 14.サイズの測定

```sql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
ユーザー postgres のパスワード:
  byte
---------
 1056768
```

- 15.一度、DB をドロップして、再度 restore します。

* 16.INSERT のみ(前準備)

```sql
DO $$
DECLARE
num constant int := 11000;
BEGIN
  RAISE NOTICE 'START %',clock_timestamp();
  FOR a IN 1000..num LOOP
  	 INSERT INTO country (country_id, country) values (a, a::text);
  END LOOP;
  RAISE NOTICE 'END %',clock_timestamp();
END$$;
```

- 17.データを書き出しておきます

```sql
psql -U postgres -d dvdrental -c "analyze;"
```

- 18.更新対象行がある状態で UPSERT 実行

```
DO $$
DECLARE
num constant int := 11000;
BEGIN
  RAISE NOTICE 'START %',clock_timestamp();
  FOR a IN 1000..num LOOP
  	 insert into country (country_id, country) values (a, a::text)
	 on conflict (country_id)
	 do update set country = a::text;
  END LOOP;
  RAISE NOTICE 'END %',clock_timestamp();
END$$;
NOTICE:  START 2022-11-15 07:02:56.024035+09
NOTICE:  END 2022-11-15 07:02:56.50013+09
DO

クエリが 499 ミリ秒 で成功しました。
```

- 16.サイズの測定

```
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
ユーザー postgres のパスワード:
  byte
---------
 1056768
(1 行)
```

- 17.一度、DB をドロップして、再度 restore します。

* 18.insert 失敗時に update する関数登録。

```sql
CREATE OR REPLACE FUNCTION insert_update
  (id int)
  RETURNS void AS $$
BEGIN
  INSERT INTO country (country_id, country) values (id, id::text);
EXCEPTION WHEN unique_violation THEN
  UPDATE country SET country = id::text WHERE country_id = id;
END;
$$ LANGUAGE plpgsql;
```

- 19.関数の実行(insert 成功パターン)

```sql
DO $$
DECLARE
num constant int := 11000;
BEGIN
  RAISE NOTICE 'START %',clock_timestamp();
  FOR a IN 1000..num LOOP
  	 PERFORM insert_update(a);
  END LOOP;
  RAISE NOTICE 'END %',clock_timestamp();
END$$;
NOTICE:  START 2022-11-15 19:07:43.742057+09
NOTICE:  END 2022-11-15 19:07:44.009101+09
DO
クエリが 301 ミリ秒 で成功しました。
```

- 20.サイズの測定

```sql
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
ユーザー postgres のパスワード:
  byte
--------
 532480
```

- 21.関数の実行(update 成功パターン)

```
DO $$
DECLARE
num constant int := 11000;
BEGIN
 RAISE NOTICE 'START %',clock_timestamp();
 FOR a IN 1000..num LOOP
 	 PERFORM insert_update(a);
 END LOOP;
 RAISE NOTICE 'END %',clock_timestamp();
END$$;
NOTICE:  START 2022-11-15 19:19:44.557191+09
NOTICE:  END 2022-11-15 19:19:46.52485+09
DO

クエリが 1 秒 989 ミリ秒 で成功しました。
```

- 22.サイズの測定

```
psql -U postgres -d dvdrental -c "analyze;"
psql -U postgres -d dvdrental -c "SELECT (relpages * 8192) as byte FROM pg_class where relname ='country';"
  byte
---------
 1572864
```
