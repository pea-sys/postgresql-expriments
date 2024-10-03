## PostgreSQL での Concurrent Index 作成時に IF NOT EXISTS に頼るのはやめましょう

`CREATE INDEX CONCURRENTLY`に失敗した場合、無効なインデックスが残ります。
公式ページにも説明があります。  
https://www.postgresql.jp/docs/16/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY

無効なインデックスがある状態で、
`CREATE INDEX CONCURRENTLY IF NOT EXISTS　~`をしてもインデックスは作成されないため意味をなしません。

以下は参考記事の実験例です。

```
createdb -U postgres sample
psql -U postgres -d sample
```

データセットアップ

```Sql
sample=# CREATE TABLE test_table (
sample(#     id serial PRIMARY KEY,
sample(#     data text
sample(# );
CREATE TABLE
sample=#
sample=# -- Insert some sample data
sample=# INSERT INTO test_table (data)
sample-# SELECT 'Data ' || generate_series(1, 1000000);
INSERT 0 1000000
sample=#
```

長時間実行クエリを疑似的に再現する関数定義

```sql
sample=# -- Function to simulate long-running query
sample=# CREATE OR REPLACE FUNCTION simulate_long_query() RETURNS void AS $$
sample$# BEGIN
sample$#     PERFORM pg_sleep(30);  -- Sleep for 30 seconds
sample$# END;
sample$# $$ LANGUAGE plpgsql;
CREATE FUNCTION
```

タイムアウト秒数を 5 秒に設定

```Sql
SET lock_timeout = '5s';
```

クライアント A で長時間クエリを実行

```Sql
sample=# BEGIN;
BEGIN
sample=*# SELECT simulate_long_query();
 simulate_long_query
---------------------

(1 行)
```

クライアント A の応答が返る前にクライアント B でインデックス作成し、アンロック待ちのタイムアウトを発生させる

```Sql
sample=# SET lock_timeout = '5s';
SET
sample=# CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_test_data ON test_table (data);
ERROR:  ロックのタイムアウトのためステートメントをキャンセルしています
```

再度、クライアント B でインデックスを作成しようとすると、既に存在するためスキップします

```Sql
sample=# CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_test_data ON test_table (data);
NOTICE:  リレーション"idx_test_data"はすでに存在します、スキップします
CREATE INDEX
```

インデックスの状態をチェックします  
`indisvalid`は、インデックスが不完全かもしれないことを意味します。

```Sql
sample=# SELECT indexrelid::regclass, indisvalid
sample-# FROM pg_index
sample-# WHERE indisvalid = false;
  indexrelid   | indisvalid
---------------+------------
 idx_test_data | f
(1 行)
```

より安全な方法は、既存のインデックス（有効または無効）をすべて削除して再作成することです。

```sql
sample=# DROP INDEX IF EXISTS idx_test_data;
DROP INDEX
sample=# CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_test_data ON test_table (data);
CREATE INDEX
sample=# SELECT indexrelid::regclass, indisvalid
sample-# FROM pg_index
sample-# WHERE indisvalid = false;
 indexrelid | indisvalid
------------+------------
(0 行)
```

[参考]

- https://www.shayon.dev/post/2024/225/stop-relying-on-if-not-exists-for-concurrent-index-creation-in-postgresql/
