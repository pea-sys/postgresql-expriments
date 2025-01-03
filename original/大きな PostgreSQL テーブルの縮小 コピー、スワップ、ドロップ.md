# 大きな PostgreSQL テーブルの縮小 コピー、スワップ、ドロップ

Postgres を停止したり、パーティション テーブルに移行したりすることなく、テーブルを効果的に縮小します

https://andyatkinson.com/copy-swap-drop-postgres-table-shrink

手順をもう少し詳しく説明します。

- 元のテーブル定義を複製し、新しい名前で同等のテーブルを作成します。
- 行のサブセットを新しいテーブルにコピーします
- テーブル名を入れ替える
- 元のテーブルを削除する

### ステップ 1: コピー

オリジナルデータ作成

```sql
sample=# CREATE TABLE events (
sample(# id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
sample(# data TEXT,
sample(# created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
sample(# );
CREATE TABLE
sample=#
sample=# CREATE INDEX ON events (data);
CREATE INDEX
```

複製テーブル作成

```sql
sample=# -- Step 1: Clone the table structure
sample=# CREATE TABLE events_intermediate (
sample(#     LIKE events INCLUDING ALL EXCLUDING INDEXES
sample(# );
CREATE TABLE
```

行のコピーが完了するまでインデックスの作成を延期します。

### 行のサブセットをコピーする

空のテーブルを作成したら、イベント テーブルからどのくらい遡ってコピーを開始するかを決定します。

```sql
sample=# -- 2. Copy a subset of rows
sample=# -- Find the first primary key id that's newer than 30 days ago
sample=# SELECT id, created_at
sample-# FROM events
sample-# WHERE created_at > (CURRENT_DATE - INTERVAL '30 days')
sample-# LIMIT 1;
 id |         created_at
----+----------------------------
  1 | 2024-09-07 06:55:03.922095
(1 行)
```

### インデックスを戻す

行のコピーが可能な限り高速になるように、最初は意図的にインデックスを省略しました。

Postgres がインデックス作成のために、より多くの並列メンテナンス ワーカー ( max_worker_processes と max_parallel_workers によって制限) を起動できるようにします。

```sql
sample=# -- Speed up index creation, example of increasing it to 1GB of memory
sample=# SET maintenance_work_mem = '1GB';
SET
sample=#
sample=# -- Allow for more parallel maintenance workers
sample=# SET max_parallel_maintenance_workers = 4;
SET
```

インデックスを作成するための十分な時間を確保するために、このタイムアウトを増やしてみてください。

```sql
sample=# -- Add time, e.g. 2 hours to provide plenty of time
sample=# SET statement_timeout = '120min';
SET
```

元のインデックス定義を確認

```sql
sample=# SELECT indexdef
sample-# FROM pg_indexes
sample-# WHERE tablename = 'events';
                             indexdef
-------------------------------------------------------------------
 CREATE UNIQUE INDEX events_pkey ON public.events USING btree (id)
 CREATE INDEX events_data_idx ON public.events USING btree (data)
(2 行)
```

少し編集してコピーテーブルにインデックスを張ります

```sql
sample=# CREATE UNIQUE INDEX events_pkey1_idx ON events_intermediate (id);
CREATE INDEX
sample=# CREATE INDEX events_data_idx1 ON events_intermediate (data);
CREATE INDEX
```

### インデックスを使用した主キー

コピーテーブルに主キーを張ります

```sql
sample=# ALTER TABLE events_intermediate
sample-# ADD CONSTRAINT events_pkey1 PRIMARY KEY
sample-# USING INDEX events_pkey1_idx;
NOTICE:  ALTER TABLE / ADD CONSTRAINT USING INDEX はインデックス"events_pkey1_idx"を"events_pkey1"にリネームします
ALTER TABLE
```

これによりテーブル定義がオリジナルとコピーで一致します

### シーケンス値を上げる

```sql
sample=# SELECT * FROM pg_sequences;
 schemaname |        sequencename        | sequenceowner | data_type | start_value | min_value |      max_value      | increment_by | cycle | cache_size | last_value
------------+----------------------------+---------------+-----------+-------------+-----------+---------------------+--------------+-------+------------+------------
 public     | events_id_seq              | postgres      | bigint    |           1 |         1 | 9223372036854775807 |            1 | f     |          1 |          2
 public     | events_intermediate_id_seq | postgres      | bigint    |           1 |         1 | 9223372036854775807 |            1 | f     |          1 |
(2 行)
```

バッファを持たせて、余裕をもってシーケンス値を上げます

```sql
sample=# -- Capture the sequence value plus the raised, as NEW_MINIMUM
sample=# SELECT setval('events_intermediate_id_seq', nextval('events_id_seq') + 1000);
 setval
--------
   1003
(1 行)
```

### ステップ 3: スワップ

```sql
BEGIN
sample=*#
sample=*# -- Rename original table to be "retired"
sample=*# ALTER TABLE events RENAME TO events_retired;
ALTER TABLE
sample=*#
sample=*# -- Rename "intermediate" table to be original table name
sample=*# ALTER TABLE events_intermediate RENAME TO events;
ALTER TABLE
sample=*#
sample=*# -- Grab one more batch of any rows committed
sample=*# -- just before this transaction
sample=*# WITH t AS (
sample(*#   SELECT MAX(id) AS max_id
sample(*#   FROM events
sample(*# )
sample-*# INSERT INTO events
sample-*# OVERRIDING SYSTEM VALUE
sample-*# SELECT *
sample-*# FROM events_retired
sample-*# WHERE id > (SELECT max_id FROM t)
sample-*# ORDER BY id
sample-*# LIMIT 1000;
INSERT 0 0
sample=*#
sample=*#
sample=*# COMMIT;
COMMIT
```

新しい小さいテーブルが入れ替わりました。前のテーブルに挿入された行が見逃されていないことを確認するために、もう一度実行してみましょう。

トランザクションの開始後にコミットされたために表示されなかった行が存在する可能性があります。

これを行うには、このステートメントは、廃止されたテーブル「events_retired」から、新しく名前が変更された「events」テーブルにコピーします。

```sql
sample=# INSERT INTO events
sample-# OVERRIDING SYSTEM VALUE
sample-# SELECT * FROM events_retired
sample-# WHERE id > (SELECT MAX(id) FROM events);
INSERT 0 0
```

この設計では、クエリされた行が利用できない短い期間が発生する可能性があります。このトレードオフがシステムで許容されるかどうかを判断する必要があります。

### ステップ 3: ドロップ

古いテーブルを削除します

```sql
sample=# -- Warning: Please review everything above.
sample=# DROP TABLE events_retired;
DROP TABLE
```
