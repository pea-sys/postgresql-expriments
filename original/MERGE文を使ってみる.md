# MERGE 文を使ってみる

PostgreSQL 15 で追加された MERGE 文を使ってみます。

> MERGE — テーブルの行を条件付きで INSERT、UPDATE、DELETE する

- Syntax

```sql
[ WITH with_query [, ...] ]
MERGE INTO target_table_name [ [ AS ] target_alias ]
USING data_source ON join_condition
when_clause [...]
```

条件分岐はいくつでも作れるし、分岐によっては何もしないということも出来ます。
https://www.percona.com/blog/using-merge-to-make-your-postgresql-more-powerful/

```sql
merge into b
using a
on b.id = a.id
when matched AND b.x = 3 THEN
do nothing
when matched AND b.x = 2 THEN
UPDATE SET x = b.x + a.x, status='updated+'
when matched and b.x = 1 THEN
UPDATE SET status = 'updated', x = 3
when not matched then
insert (id,x,status) values (a.id,a.x,a.status);
```

---

すでに実験している方がいたのでトレースします。
https://qiita.com/fujii_masao/items/462bac9f6a107d6134c4

※TABLESAMPLE 知らなかったので勉強になりました

| 検証パターン                                 | INSERT ON CONFLICT | MERGE           |
| -------------------------------------------- | ------------------ | --------------- |
| ①1000 万件を INSERT                          | 5341.310 ミリ秒    | 2272.710 ミリ秒 |
| ② 約 500 万件を INSERT、約 500 万件を UPDATE | 8708.554 ミリ秒    | 1510.876 ミリ秒 |
| ③ 1000 万件を UPDATE                         | 7323.171 ミリ秒    | 6513.654 ミリ秒 |

- バージョン確認

```
postgres=# select version();
                          version
------------------------------------------------------------
 PostgreSQL 15.2, compiled by Visual C++ build 1914, 64-bit
```

```
PS C:\Users\user> psql -U postgres -p 5432 -d postgres
ユーザー postgres のパスワード:
psql (15.2)
"help"でヘルプを表示します。

postgres=# -- psqlの時間計測機能を有効化
postgres=# \timing on
タイミングは on です。
postgres=#
postgres=# -- UPSERT元と先のテーブルとしてsrcとdstを作成する。
postgres=# -- できるだけUPSERT処理そのものの時間計測となるように、
postgres=# -- テーブルはUNLOGGEDで作成して、autovacuumを無効化する。
postgres=# DROP TABLE IF EXISTS src, dst;
NOTICE:  テーブル"src"は存在しません、スキップします
NOTICE:  テーブル"dst"は存在しません、スキップします
DROP TABLE
時間: 7.389 ミリ秒
postgres=# CREATE UNLOGGED TABLE src
postgres-#   (key bigint PRIMARY KEY, val bigint)
postgres-#   WITH (autovacuum_enabled=false);
CREATE TABLE
時間: 26.196 ミリ秒
postgres=# CREATE UNLOGGED TABLE dst
postgres-#   (key bigint PRIMARY KEY, val bigint)
postgres-#   WITH (autovacuum_enabled=false);
CREATE TABLE
時間: 10.901 ミリ秒
postgres=#
postgres=# -- UPSERT元テーブルsrcに1000万件を挿入する。
postgres=# INSERT INTO src VALUES (generate_series(1, 1000000), 1);
INSERT 0 1000000
時間: 2436.690 ミリ秒(00:02.437)
postgres=# VACUUM ANALYZE;
VACUUM
時間: 541.723 ミリ秒
postgres=#
postgres=# -- 計測中にCHECKPOINTが走らないように、事前に実行する。
postgres=# CHECKPOINT;
CHECKPOINT
時間: 411.708 ミリ秒
postgres=# TRUNCATE dst;
TRUNCATE TABLE
時間: 18.065 ミリ秒
postgres=#
postgres=# -- 空のテーブルdstに対してINSERT ON CONFLICTを実行して、
postgres=# -- 「① 1000万件をINSERT」の実行時間を計測する。
VACUUM ANALYZE;
postgres=# INSERT INTO dst AS d SELECT key, val FROM src
postgres-#   ON CONFLICT (key) DO UPDATE SET val = d.val + EXCLUDED.val;
INSERT 0 1000000
時間: 5341.310 ミリ秒(00:05.341)
postgres=#
postgres=# -- 1000万件格納済のテーブルdstに対してINSERT ON CONFLICTを実行して、
postgres=# -- 「③ 1000万件をUPDATE」の実行時間を計測する。
VACUUM ANALYZE;
postgres=# INSERT INTO dst AS d SELECT key, val FROM src
postgres-#   ON CONFLICT (key) DO UPDATE SET val = d.val + EXCLUDED.val;
INSERT 0 1000000
時間: 8708.554 ミリ秒(00:08.709)
postgres=#
postgres=# -- テーブルdstから50%の約500万件をランダムに削除する。
postgres=# DELETE FROM dst WHERE key IN
postgres-#   (SELECT key FROM dst TABLESAMPLE BERNOULLI(50));
DELETE 500527
時間: 1510.876 ミリ秒(00:01.511)
postgres=#
postgres=# -- 約500万件格納済のテーブルdstに対してINSERT ON CONFLICTを実行して、
postgres=# -- 「② 約500万件をINSERT、約500万件をUPDATE」の実行時間を計測する。
VACUUM ANALYZE;
postgres=# INSERT INTO dst AS d SELECT key, val FROM src
postgres-#   ON CONFLICT (key) DO UPDATE SET val = d.val + EXCLUDED.val;
INSERT 0 1000000
時間: 7323.171 ミリ秒(00:07.323)
postgres=#
postgres=# -- 計測中にCHECKPOINTが走らないように、事前に実行する。
postgres=# -- テーブルdstを空にする。
postgres=# CHECKPOINT;
CHECKPOINT
時間: 454.771 ミリ秒
postgres=# TRUNCATE dst;
TRUNCATE TABLE
時間: 39.755 ミリ秒
postgres=#
postgres=# -- 空のテーブルdstに対してMERGEを実行して、
postgres=# -- 「① 1000万件をINSERT」の実行時間を計測する。
VACUUM ANALYZE;
postgres=# MERGE INTO dst AS d USING src AS s ON d.key = s.key
postgres-#   WHEN MATCHED THEN UPDATE SET val = d.val + s.val
postgres-#   WHEN NOT MATCHED THEN INSERT VALUES (s.key, s.val);
MERGE 1000000
時間: 2272.710 ミリ秒(00:02.273)
postgres=#
postgres=# -- 1000万件格納済のテーブルdstに対してMERGEを実行して、
postgres=# -- 「③ 1000万件をUPDATE」の実行時間を計測する。
VACUUM ANALYZE;
postgres=# MERGE INTO dst AS d USING src AS s ON d.key = s.key
postgres-#   WHEN MATCHED THEN UPDATE SET val = d.val + s.val
postgres-#   WHEN NOT MATCHED THEN INSERT VALUES (s.key, s.val);
MERGE 1000000
時間: 6626.397 ミリ秒(00:06.626)
postgres=#
postgres=# -- テーブルdstから50%の約500万件をランダムに削除する。
postgres=# DELETE FROM dst WHERE key IN
postgres-#   (SELECT key FROM dst TABLESAMPLE BERNOULLI(50));
DELETE 500020
時間: 1348.767 ミリ秒(00:01.349)
postgres=#
postgres=# -- 約500万件格納済のテーブルdstに対してMERGEを実行して、
postgres=# -- 「② 約500万件をINSERT、約500万件をUPDATE」の実行時間を計測する。
VACUUM ANALYZE;
postgres=# MERGE INTO dst AS d USING src AS s ON d.key = s.key
postgres-#   WHEN MATCHED THEN UPDATE SET val = d.val + s.val
postgres-#   WHEN NOT MATCHED THEN INSERT VALUES (s.key, s.val);
MERGE 1000000
時間: 6513.654 ミリ秒(00:06.514)
```
