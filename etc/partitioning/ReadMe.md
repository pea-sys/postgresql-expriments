# Partitioning

次の資料で紹介されていたスクリプトを元に partitioning の動作確認を行います。

---

スクリプトの提供元  
https://momjian.us/main/  
スライド  
https://momjian.us/main/writings/pgsql/partitioning.pdf

---

### [Setup]

※文字列のソート結果が変わってくるのでロケールの設定等重要

```
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF-8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';"
psql -U postgres -p 5432 -d sample
sample=# \pset footer off
sample=# \pset null (null)
Null表示は"(null)"です。
```

### [Range Partitioned Table Creation]

```sql
sample=# CREATE TABLE range_partitioned (name TEXT)PARTITION BY RANGE (name);
CREATE TABLE
sample=# CREATE TABLE range_partition_less_j PARTITION OF range_partitioned FOR VALUES FROM (MINVALUE) TO ('j');
CREATE TABLE
sample=# CREATE TABLE range_partition_j_to_s PARTITION OF range_partitioned FOR VALUES FROM ('j') TO ('s');
CREATE TABLE
sample=# CREATE TABLE range_partition_s_greater PARTITION OF range_partitioned FOR VALUES FROM ('s') TO (MAXVALUE);
CREATE TABLE
```

### [DEFAULT Partition Table Creation]

レンジ・パーティション・テーブルでは、NULL 格納のために DEFAULT パーティションが必要です。

```sql
sample=# CREATE TABLE range_partition_nulls
sample-# PARTITION OF range_partitioned
sample-# (CHECK (name IS NULL))
sample-# DEFAULT;
CREATE TABLE
```

### [The Result]

```sql
sample=# \d+ range_partitioned
                      パーティションテーブル"public.range_partitioned"
  列  | タイプ | 照合順序 | Null 値を許容 | デフォルト | ストレージ | 圧縮 | 統計目標 | 説明
------+--------+----------+---------------+------------+------------+------+----------+------
 name | text   |          |               |            | extended   |      |          |
パーティションキー: RANGE (name)
パーティション: range_partition_j_to_s FOR VALUES FROM ('j') TO ('s'),
                range_partition_less_j FOR VALUES FROM (MINVALUE) TO ('j'),
                range_partition_s_greater FOR VALUES FROM ('s') TO (MAXVALUE),
                range_partition_nulls DEFAULT
```

### [Hash Partitioned Table Creation]

```sql
sample=# CREATE TABLE hash_partitioned (name TEXT) PARTITION BY HASH (name);
CREATE TABLE
sample=# CREATE TABLE hash_partition_mod_0 PARTITION OF hash_partitioned FOR VALUES WITH (MODULUS 3, REMAINDER 0);
CREATE TABLE
sample=# CREATE TABLE hash_partition_mod_1 PARTITION OF hash_partitioned FOR VALUES WITH (MODULUS 3, REMAINDER 1);
CREATE TABLE
sample=# CREATE TABLE hash_partition_mod_2 PARTITION OF hash_partitioned FOR VALUES WITH (MODULUS 3, REMAINDER 2);
CREATE TABLE
```

### [The Result]

```
sample=# \d+ hash_partitioned
                       パーティションテーブル"public.hash_partitioned"
  列  | タイプ | 照合順序 | Null 値を許容 | デフォルト | ストレージ | 圧縮 | 統計目標 | 説明
------+--------+----------+---------------+------------+------------+------+----------+------
 name | text   |          |               |            | extended   |      |          |
パーティションキー: HASH (name)
パーティション: hash_partition_mod_0 FOR VALUES WITH (modulus 3, remainder 0),
                hash_partition_mod_1 FOR VALUES WITH (modulus 3, remainder 1),
                hash_partition_mod_2 FOR VALUES WITH (modulus 3, remainder 2)
```

### [List Partitioned Table Creation]

```sql
sample=# CREATE TYPE employment_status_type AS ENUM ('employed', 'unemployed', 'retired');
CREATE TYPE
sample=# CREATE TABLE list_partitioned (    name TEXT,    employment_status employment_status_type) PARTITION BY LIST (employment_status);
CREATE TABLE
sample=# CREATE TABLE list_partition_employed PARTITION OF list_partitioned FOR VALUES IN ('employed');
CREATE TABLE
sample=# CREATE TABLE list_partition_unemployed PARTITION OF list_partitioned FOR VALUES IN ('unemployed');
CREATE TABLE
sample=# CREATE TABLE list_partition_retired_and_null PARTITION OF list_partitioned FOR VALUES IN ('retired', NULL);
CREATE TABLE
```

### [The Result]

```sql
sample=# \d+ list_partitioned
                                     パーティションテーブル"public.list_partitioned"
        列         |         タイプ         | 照合順序 | Null 値を許容 | デフォルト | ストレージ | 圧縮 | 統計目標 | 説 明
-------------------+------------------------+----------+---------------+------------+------------+------+----------+------
 name              | text                   |          |               |            | extended   |      |          |
 employment_status | employment_status_type |          |               |            | plain      |      |          |
パーティションキー: LIST (employment_status)
パーティション: list_partition_employed FOR VALUES IN ('employed'),
                list_partition_retired_and_null FOR VALUES IN ('retired', NULL),
                list_partition_unemployed FOR VALUES IN ('unemployed')
```

### [Populating the Range Partitioned Table]

```sql
sample=# INSERT INTO range_partitioned SELECT(SELECT initcap(string_agg(x, '')) FROM (SELECT chr(ascii('a') + floor(random() * 26)::integer) FROM generate_series(1, 2 + (random() * 8)::integer + b * 0)) AS y(x)) FROM generate_series(1, 100000) AS a(b);
INSERT 0 100000
```

### [Populating the Hash Partitioned Table]

```sql
sample=# INSERT INTO hash_partitioned SELECT(SELECT initcap(string_agg(x, '')) FROM (SELECT chr(ascii('a') + floor(random() * 26)::integer) FROM generate_series(1, 2 + (random() * 8)::integer + b * 0)) AS y(x)) FROM generate_series(1, 100000) AS a(b);
INSERT 0 100000
```

### [Populating the List Partitioned Table]

```sql
sample=# INSERT INTO list_partitioned SELECT(SELECT initcap(string_agg(x, '')) FROM (SELECT chr(ascii('a') + floor(random() * 26)::integer) FROM generate_series(1, 2 + (random() * 8)::integer + b * 0)) AS y(x)),(SELECT CASE floor(random() * 3 + b * 0) WHEN 0 THEN 'employed'::employment_status_type WHEN 1 THEN 'unemployed'::employment_status_type WHEN 2 THEN 'retired'::employment_status_type END) FROM generate_series(1, 100000) AS a(b);
INSERT 0 100000
```

### [Inserting NULL Values]

```sql
sample=# INSERT INTO range_partitioned VALUES (NULL);
INSERT INTO hash_partitioned VALUES (NULL);
INSERT INTO list_partitioned VALUES ('test', NULL);
INSERT 0 1
INSERT 0 1
INSERT 0 1
```

### [Creating Indexes]

```sql
sample=# CREATE INDEX i_range_partitioned ON range_partitioned (name);
CREATE INDEX i_hash_partitioned ON hash_partitioned (name);
CREATE INDEX i_list_partitioned ON list_partitioned (name);
CREATE INDEX
CREATE INDEX
CREATE INDEX
sample=# ANALYZE;
ANALYZE
```

### [Where are NULLs Stored?]

```sql
sample=# SELECT *, tableoid::regclass FROM  range_partitioned WHERE name IS NULL;
  name  |       tableoid
--------+-----------------------
 (null) | range_partition_nulls
sample=# SELECT *, tableoid::regclass FROM  hash_partitioned WHERE name IS NULL;
  name  |       tableoid
--------+----------------------
 (null) | hash_partition_mod_0
sample=# SELECT *, tableoid::regclass FROM  list_partitioned WHERE employment_status IS NULL;
 name | employment_status |            tableoid
------+-------------------+---------------------------------
 test | (null)            | list_partition_retired_and_null
```

### [First Five Range Partitioned Rows]

```sql
sample=# SELECT *, tableoid::regclass FROM  range_partitioned ORDER BY 2, 1 LIMIT 5;
 name |        tableoid
------+------------------------
 Aa   | range_partition_less_j
 Aa   | range_partition_less_j
 Aa   | range_partition_less_j
 Aa   | range_partition_less_j
 Aa   | range_partition_less_j
```

### [Random Range Partitioned Rows]

```sql
sample=# WITH sample AS(SELECT *, tableoid::regclass FROM  range_partitioned ORDER BY random() LIMIT 5) SELECT * FROM sample ORDER BY 2, 1;
  name  |        tableoid
--------+------------------------
 Gvidgi | range_partition_less_j
 Kw     | range_partition_less_j
 Mkpcvx | range_partition_less_j
 Qvgsk  | range_partition_less_j
 Xiqzvi | range_partition_less_j
```

### [Random Hash Partitioned Rows]

```sql
sample=# WITH sample AS( SELECT *, tableoid::regclass FROM  hash_partitioned ORDER BY random() LIMIT 5) SELECT * FROM sample ORDER BY 2, 1;
  name   |       tableoid
---------+----------------------
 Ewmhkb  | hash_partition_mod_0
 Kvel    | hash_partition_mod_0
 Dv      | hash_partition_mod_1
 Jzea    | hash_partition_mod_1
 Janzgsi | hash_partition_mod_2
```

### [Random List Partitioned Rows]

```sql
sample=# WITH sample AS(SELECT *, tableoid::regclass FROM  list_partitioned ORDER BY random() LIMIT 5) SELECT * FROM sample ORDER BY 3, 2, 1;
    name    | employment_status |            tableoid
------------+-------------------+---------------------------------
 Odkxbahge  | employed          | list_partition_employed
 Txpwzrhwq  | employed          | list_partition_employed
 Gwuk       | unemployed        | list_partition_unemployed
 Hoeokhavun | retired           | list_partition_retired_and_null
 Vmx        | retired           | list_partition_retired_and_null
```

### [Selecting Range Partition Boundaries]

```sql
sample=# SHOW lc_collate;
 lc_collate
-------------
 en_US.UTF-8


sample=# SELECT 'a' < 'J' AND 'J' < 'z';
 ?column?
----------
 t


sample=# SELECT 'ja' < 'Jb' AND 'Jc' < 'jd';
 ?column?
----------
 t


sample=# SELECT 'ja' < 'Ja';
 ?column?
----------
 t


sample=# SELECT 'island' < 'Island' AND 'islaNd' < 'iSland';
 ?column?
----------
 t

```

### [Pruning Using NULL Constants: Stage 1]

```sql
sample=# EXPLAIN SELECT * FROM range_partitioned WHERE name IS NULL;
                                       QUERY PLAN
----------------------------------------------------------------------------------------
 Seq Scan on range_partition_nulls range_partitioned  (cost=0.00..1.01 rows=1 width=32)
   Filter: (name IS NULL)


sample=# EXPLAIN SELECT * FROM hash_partitioned WHERE name IS NULL;
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using hash_partition_mod_0_name_idx on hash_partition_mod_0 hash_partitioned  (cost=0.29..8.31 rows=1 width=7)
   Index Cond: (name IS NULL)


sample=# EXPLAIN SELECT * FROM list_partitioned WHERE employment_status IS NULL;
                                            QUERY PLAN
---------------------------------------------------------------------------------------------------
 Seq Scan on list_partition_retired_and_null list_partitioned  (cost=0.00..504.30 rows=1 width=10)
   Filter: (employment_status IS NULL)



```

### [Pruning Using Non-NULL Constants: Stage 1]

```sql
sample=# EXPLAIN SELECT * FROM range_partitioned WHERE name = 'Ma';
                                            QUERY PLAN
--------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on range_partition_j_to_s range_partitioned  (cost=4.40..48.30 rows=14 width=6)
   Recheck Cond: (name = 'Ma'::text)
   ->  Bitmap Index Scan on range_partition_j_to_s_name_idx  (cost=0.00..4.40 rows=14 width=0)
         Index Cond: (name = 'Ma'::text)


sample=# EXPLAIN SELECT * FROM hash_partitioned WHERE name = 'Ma';
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using hash_partition_mod_2_name_idx on hash_partition_mod_2 hash_partitioned  (cost=0.29..8.31 rows=1 width=6)
   Index Cond: (name = 'Ma'::text)


sample=# EXPLAIN SELECT * FROM  list_partitioned WHERE employment_status = 'retired';
                                              QUERY PLAN
-------------------------------------------------------------------------------------------------------
 Seq Scan on list_partition_retired_and_null list_partitioned  (cost=0.00..587.13 rows=33129 width=10)
   Filter: (employment_status = 'retired'::employment_status_type)
```

### [Use of Pruning and Per-Partition Index: Stage 1]

```sql
sample=# EXPLAIN SELECT * FROM list_partitioned WHERE employment_status = 'retired' AND      name = 'Ma';
                                                QUERY PLAN
----------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on list_partition_retired_and_null list_partitioned  (cost=4.34..28.23 rows=7 width=10)
   Recheck Cond: (name = 'Ma'::text)
   Filter: (employment_status = 'retired'::employment_status_type)
   ->  Bitmap Index Scan on list_partition_retired_and_null_name_idx  (cost=0.00..4.34 rows=7 width=0)
         Index Cond: (name = 'Ma'::text)


sample=# \d+ list_partitioned
                                     パーティションテーブル"public.list_partitioned"
        列         |         タイプ         | 照合順序 | Null 値を許容 | デフォルト | ストレージ | 圧縮 | 統計目標 | 説 明
-------------------+------------------------+----------+---------------+------------+------------+------+----------+------
 name              | text                   |          |               |            | extended   |      |          |
 employment_status | employment_status_type |          |               |            | plain      |      |          |
パーティションキー: LIST (employment_status)
インデックス:
    "i_list_partitioned" btree (name)
パーティション: list_partition_employed FOR VALUES IN ('employed'),
                list_partition_retired_and_null FOR VALUES IN ('retired', NULL),
                list_partition_unemployed FOR VALUES IN ('unemployed')
```

### [Pruning of Custom-Plan Prepared Statements: Stage 1]

```sql
sample=# PREPARE part_test AS SELECT * FROM range_partitioned WHERE name = $1;
PREPARE
sample=# EXPLAIN  EXECUTE part_test('Ba');
                                            QUERY PLAN
--------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on range_partition_less_j range_partitioned  (cost=4.37..37.08 rows=10 width=7)
   Recheck Cond: (name = 'Ba'::text)
   ->  Bitmap Index Scan on range_partition_less_j_name_idx  (cost=0.00..4.37 rows=10 width=0)
         Index Cond: (name = 'Ba'::text)


sample=# EXPLAIN  EXECUTE part_test('Ma');
                                            QUERY PLAN
--------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on range_partition_j_to_s range_partitioned  (cost=4.40..48.30 rows=14 width=6)
   Recheck Cond: (name = 'Ma'::text)
   ->  Bitmap Index Scan on range_partition_j_to_s_name_idx  (cost=0.00..4.40 rows=14 width=0)
         Index Cond: (name = 'Ma'::text)


sample=# EXPLAIN  EXECUTE part_test('Ta');
                                             QUERY PLAN
-----------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on range_partition_s_greater range_partitioned  (cost=4.40..50.17 rows=15 width=6)
   Recheck Cond: (name = 'Ta'::text)
   ->  Bitmap Index Scan on range_partition_s_greater_name_idx  (cost=0.00..4.40 rows=15 width=0)
         Index Cond: (name = 'Ta'::text)
```

### [Pruning of Generic-Plan Prepared Statements: Stage 2]

```sql
sample=# SET plan_cache_mode TO force_generic_plan;
SET
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) EXECUTE part_test('Ma');
                                                             QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------
 Append (actual rows=15 loops=1)
   Subplans Removed: 2
   ->  Index Only Scan using range_partition_j_to_s_name_idx on range_partition_j_to_s range_partitioned_1 (actual rows=15 loops=1)
         Index Cond: (name = $1)
         Heap Fetches: 0
(5 行)


sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) EXECUTE part_test('Ta');
                                                                QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Append (actual rows=15 loops=1)
   Subplans Removed: 2
   ->  Index Only Scan using range_partition_s_greater_name_idx on range_partition_s_greater range_partitioned_1 (actual rows=15 loops=1)
         Index Cond: (name = $1)
         Heap Fetches: 0
(5 行)
sample=# RESET plan_cache_mode;
RESET
```

### [Pruning of IMMUTABLE Function Calls]

```sql
sample=# \do+ ||
                                                                演算子一覧
  スキーマ  | 名前 |      左辺の型      |      右辺の型      |      結果の型      |      関数       |                説 明
------------+------+--------------------+--------------------+--------------------+-----------------+-------------------------------------
 pg_catalog | ||   | anycompatible      | anycompatiblearray | anycompatiblearray | array_prepend   | prepend element onto front of array
 pg_catalog | ||   | anycompatiblearray | anycompatible      | anycompatiblearray | array_append    | append element onto end of array
 pg_catalog | ||   | anycompatiblearray | anycompatiblearray | anycompatiblearray | array_cat       | concatenate
 pg_catalog | ||   | anynonarray        | text               | text               | anytextcat      | concatenate
 pg_catalog | ||   | bit varying        | bit varying        | bit varying        | bitcat          | concatenate
 pg_catalog | ||   | bytea              | bytea              | bytea              | byteacat        | concatenate
 pg_catalog | ||   | jsonb              | jsonb              | jsonb              | jsonb_concat    | concatenate
 pg_catalog | ||   | text               | anynonarray        | text               | textanycat      | concatenate
 pg_catalog | ||   | text               | text               | text               | textcat         | concatenate
 pg_catalog | ||   | tsquery            | tsquery            | tsquery            | tsquery_or      | OR-concatenate
 pg_catalog | ||   | tsvector           | tsvector           | tsvector           | tsvector_concat | concatenate
(11 行)


sample=# \x on
拡張表示は on です。
sample=# \df+ textcat
関数一覧
-[ RECORD 1 ]----+------------------------------
スキーマ         | pg_catalog
名前             | textcat
結果のデータ型   | text
引数のデータ型   | text, text
タイプ           | 関数
関数の変動性分類 | IMMUTABLE
並列実行         | 安全
所有者           | postgres
セキュリティ     | 起動ロール
アクセス権限     |
手続き言語       | internal
ソースコード     | textcat
説明             | implementation of || operator


sample=# \x off
拡張表示は off です。
```

### [Pruning of IMMUTABLE Function Calls: Stage 1]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT *, tableoid::regclass FROM range_partitioned WHERE name = 'M' || 'a';
                                      QUERY PLAN
---------------------------------------------------------------------------------------
 Bitmap Heap Scan on range_partition_j_to_s range_partitioned (actual rows=15 loops=1)
   Recheck Cond: (name = 'Ma'::text)
   Heap Blocks: exact=15
   ->  Bitmap Index Scan on range_partition_j_to_s_name_idx (actual rows=15 loops=1)
         Index Cond: (name = 'Ma'::text)
```

### [Pruning of STABLE Function Calls]

```sql
sample=# \x on
拡張表示は on です。
sample=# \df+ concat
関数一覧
-[ RECORD 1 ]----+-------------------
スキーマ         | pg_catalog
名前             | concat
結果のデータ型   | text
引数のデータ型   | VARIADIC "any"
タイプ           | 関数
関数の変動性分類 | STABLE
並列実行         | 安全
所有者           | postgres
セキュリティ     | 起動ロール
アクセス権限     |
手続き言語       | internal
ソースコード     | text_concat
説明             | concatenate values


sample=# \x off
拡張表示は off です。
```

### [Pruning of STABLE Function Calls: Stage 2]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT *, tableoid::regclass FROM range_partitioned WHERE name = concat('M', 'a');
                                          QUERY PLAN
-----------------------------------------------------------------------------------------------
 Append (actual rows=15 loops=1)
   Subplans Removed: 2
   ->  Bitmap Heap Scan on range_partition_j_to_s range_partitioned_1 (actual rows=15 loops=1)
         Recheck Cond: (name = concat('M', 'a'))
         Heap Blocks: exact=15
         ->  Bitmap Index Scan on range_partition_j_to_s_name_idx (actual rows=15 loops=1)
               Index Cond: (name = concat('M', 'a'))
```

### [Pruning of Subqueries: Stage 3]

```sql
sample=# CREATE TABLE nested_outer (name) AS VALUES ('Pa'), ('Qa'), ('Ra');
ANALYZE nested_outer;
SELECT 3
ANALYZE
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM range_partitioned WHERE name IN (SELECT * FROM nested_outer);
                                                                QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop (actual rows=31 loops=1)
   ->  HashAggregate (actual rows=3 loops=1)
         Group Key: nested_outer.name
         Batches: 1  Memory Usage: 24kB
         ->  Seq Scan on nested_outer (actual rows=3 loops=1)
   ->  Append (actual rows=10 loops=3)
         ->  Index Only Scan using range_partition_less_j_name_idx on range_partition_less_j range_partitioned_1 (never executed)
               Index Cond: (name = nested_outer.name)
               Heap Fetches: 0
         ->  Index Only Scan using range_partition_j_to_s_name_idx on range_partition_j_to_s range_partitioned_2 (actual rows=10 loops=3)
               Index Cond: (name = nested_outer.name)
               Heap Fetches: 0
         ->  Index Only Scan using range_partition_s_greater_name_idx on range_partition_s_greater range_partitioned_3 (never executed)
               Index Cond: (name = nested_outer.name)
               Heap Fetches: 0
         ->  Seq Scan on range_partition_nulls range_partitioned_4 (never executed)
               Filter: (nested_outer.name = name)
```

### [Pruning of Joins: Stage 3]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM nested_outer JOIN range_partitioned USING (name);
                                                                QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop (actual rows=31 loops=1)
   ->  Seq Scan on nested_outer (actual rows=3 loops=1)
   ->  Append (actual rows=10 loops=3)
         ->  Index Only Scan using range_partition_less_j_name_idx on range_partition_less_j range_partitioned_1 (never executed)
               Index Cond: (name = nested_outer.name)
               Heap Fetches: 0
         ->  Index Only Scan using range_partition_j_to_s_name_idx on range_partition_j_to_s range_partitioned_2 (actual rows=10 loops=3)
               Index Cond: (name = nested_outer.name)
               Heap Fetches: 0
         ->  Index Only Scan using range_partition_s_greater_name_idx on range_partition_s_greater range_partitioned_3 (never executed)
               Index Cond: (name = nested_outer.name)
               Heap Fetches: 0
         ->  Seq Scan on range_partition_nulls range_partitioned_4 (never executed)
               Filter: (nested_outer.name = name)
```

### [Aggregates Without partitionwise_aggregate: Range]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT name, COUNT(*) FROM range_partitioned GROUP BY name;
                                            QUERY PLAN
---------------------------------------------------------------------------------------------------
 HashAggregate (actual rows=90491 loops=1)
   Group Key: range_partitioned.name
   Batches: 5  Memory Usage: 8241kB  Disk Usage: 1552kB
   ->  Append (actual rows=100001 loops=1)
         ->  Seq Scan on range_partition_less_j range_partitioned_1 (actual rows=34556 loops=1)
         ->  Seq Scan on range_partition_j_to_s range_partitioned_2 (actual rows=34650 loops=1)
         ->  Seq Scan on range_partition_s_greater range_partitioned_3 (actual rows=30794 loops=1)
         ->  Seq Scan on range_partition_nulls range_partitioned_4 (actual rows=1 loops=1)
```

### [Aggregates Without partitionwise_aggregate: Hash]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT name, COUNT(*) FROM hash_partitioned GROUP BY name;
                                         QUERY PLAN
---------------------------------------------------------------------------------------------
 HashAggregate (actual rows=90656 loops=1)
   Group Key: hash_partitioned.name
   Batches: 5  Memory Usage: 8241kB  Disk Usage: 1552kB
   ->  Append (actual rows=100001 loops=1)
         ->  Seq Scan on hash_partition_mod_0 hash_partitioned_1 (actual rows=33344 loops=1)
         ->  Seq Scan on hash_partition_mod_1 hash_partitioned_2 (actual rows=33187 loops=1)
         ->  Seq Scan on hash_partition_mod_2 hash_partitioned_3 (actual rows=33470 loops=1)
```

### [Aggregates Without partitionwise_aggregate: List]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT employment_status, COUNT(*) FROM list_partitioned GROUP BY employment_status;
                                               QUERY PLAN
--------------------------------------------------------------------------------------------------------
 HashAggregate (actual rows=4 loops=1)
   Group Key: list_partitioned.employment_status
   Batches: 1  Memory Usage: 24kB
   ->  Append (actual rows=100001 loops=1)
         ->  Seq Scan on list_partition_employed list_partitioned_1 (actual rows=33395 loops=1)
         ->  Seq Scan on list_partition_unemployed list_partitioned_2 (actual rows=33476 loops=1)
         ->  Seq Scan on list_partition_retired_and_null list_partitioned_3 (actual rows=33130 loops=1)
```

### [Aggregates With partitionwise_aggregate: Range]

```sql
sample=# SET enable_partitionwise_aggregate = true;
SET
sample=# SET cpu_tuple_cost = 0;
SET
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT name, COUNT(*) FROM range_partitioned GROUP BY name;
                                            QUERY PLAN
---------------------------------------------------------------------------------------------------
 Append (actual rows=90491 loops=1)
   ->  HashAggregate (actual rows=31327 loops=1)
         Group Key: range_partitioned.name
         Batches: 1  Memory Usage: 4113kB
         ->  Seq Scan on range_partition_less_j range_partitioned (actual rows=34556 loops=1)
   ->  HashAggregate (actual rows=31412 loops=1)
         Group Key: range_partitioned_1.name
         Batches: 1  Memory Usage: 4113kB
         ->  Seq Scan on range_partition_j_to_s range_partitioned_1 (actual rows=34650 loops=1)
   ->  HashAggregate (actual rows=27751 loops=1)
         Group Key: range_partitioned_2.name
         Batches: 1  Memory Usage: 3857kB
         ->  Seq Scan on range_partition_s_greater range_partitioned_2 (actual rows=30794 loops=1)
   ->  HashAggregate (actual rows=1 loops=1)
         Group Key: range_partitioned_3.name
         Batches: 1  Memory Usage: 24kB
         ->  Seq Scan on range_partition_nulls range_partitioned_3 (actual rows=1 loops=1)
```

### [Aggregates With partitionwise_aggregate: Hash]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT name, COUNT(*) FROM hash_partitioned GROUP BY name;
                                         QUERY PLAN
---------------------------------------------------------------------------------------------
 Append (actual rows=90656 loops=1)
   ->  HashAggregate (actual rows=30320 loops=1)
         Group Key: hash_partitioned.name
         Batches: 1  Memory Usage: 4113kB
         ->  Seq Scan on hash_partition_mod_0 hash_partitioned (actual rows=33344 loops=1)
   ->  HashAggregate (actual rows=30078 loops=1)
         Group Key: hash_partitioned_1.name
         Batches: 1  Memory Usage: 4113kB
         ->  Seq Scan on hash_partition_mod_1 hash_partitioned_1 (actual rows=33187 loops=1)
   ->  HashAggregate (actual rows=30258 loops=1)
         Group Key: hash_partitioned_2.name
         Batches: 1  Memory Usage: 4113kB
         ->  Seq Scan on hash_partition_mod_2 hash_partitioned_2 (actual rows=33470 loops=1)
```

### [Aggregates With partitionwise_aggregate: List]

```sql
sample=# RESET cpu_tuple_cost;
RESET
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT employment_status, COUNT(*) FROM list_partitioned GROUP BY employment_status;
                                               QUERY PLAN
--------------------------------------------------------------------------------------------------------
 Append (actual rows=4 loops=1)
   ->  HashAggregate (actual rows=1 loops=1)
         Group Key: list_partitioned.employment_status
         Batches: 1  Memory Usage: 24kB
         ->  Seq Scan on list_partition_employed list_partitioned (actual rows=33395 loops=1)
   ->  HashAggregate (actual rows=1 loops=1)
         Group Key: list_partitioned_1.employment_status
         Batches: 1  Memory Usage: 24kB
         ->  Seq Scan on list_partition_unemployed list_partitioned_1 (actual rows=33476 loops=1)
   ->  HashAggregate (actual rows=2 loops=1)
         Group Key: list_partitioned_2.employment_status
         Batches: 1  Memory Usage: 24kB
         ->  Seq Scan on list_partition_retired_and_null list_partitioned_2 (actual rows=33130 loops=1)
sample=# RESET enable_partitionwise_aggregate;
RESET
```

### [Cross Partition Join: Setup]

```sql
sample=# CREATE TABLE range_partitioned2 (name TEXT) PARTITION BY RANGE (name);
CREATE TABLE range_partition_less_j2 PARTITION OF range_partitioned2 FOR VALUES FROM (MINVALUE) TO ('j');
CREATE TABLE range_partition_j_to_s2 PARTITION OF range_partitioned2 FOR VALUES FROM ('j') TO ('s');
CREATE TABLE range_partition_s_greater2 PARTITION OF range_partitioned2 FOR VALUES FROM ('s') TO (MAXVALUE);
CREATE TABLE range_partition_nulls2 PARTITION OF range_partitioned2(CHECK (name IS NULL)) DEFAULT;
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
```

### [Cross Partition Join: Populate]

```sql
sample=# INSERT INTO range_partitioned2 SELECT(SELECT initcap(string_agg(x, '')) FROM (SELECT chr(ascii('a') + floor(random() * 26)::integer)  FROM generate_series(1, 2 + (random() * 8)::integer + b * 0)) AS y(x)) FROM generate_series(1, 100000) AS a(b);
ANALYZE;
INSERT 0 100000
ANALYZE
```

### [Cross Partition Join Without partitionwise_join]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM range_partitioned JOIN range_partitioned2 USING (name);
                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Hash Join (actual rows=67354 loops=1)
   Hash Cond: (range_partitioned.name = range_partitioned2.name)
   ->  Append (actual rows=100001 loops=1)
         ->  Seq Scan on range_partition_less_j range_partitioned_1 (actual rows=34556 loops=1)
         ->  Seq Scan on range_partition_j_to_s range_partitioned_2 (actual rows=34650 loops=1)
         ->  Seq Scan on range_partition_s_greater range_partitioned_3 (actual rows=30794 loops=1)
         ->  Seq Scan on range_partition_nulls range_partitioned_4 (actual rows=1 loops=1)
   ->  Hash (actual rows=100000 loops=1)
         Buckets: 131072  Batches: 1  Memory Usage: 4833kB
         ->  Append (actual rows=100000 loops=1)
               ->  Seq Scan on range_partition_less_j2 range_partitioned2_1 (actual rows=34747 loops=1)
               ->  Seq Scan on range_partition_j_to_s2 range_partitioned2_2 (actual rows=34575 loops=1)
               ->  Seq Scan on range_partition_s_greater2 range_partitioned2_3 (actual rows=30678 loops=1)
               ->  Seq Scan on range_partition_nulls2 range_partitioned2_4 (actual rows=0 loops=1)
```

### [Cross Partition Join With partitionwise_join]

```sql
sample=# SET enable_partitionwise_join = true;
EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM range_partitioned JOIN range_partitioned2 USING (name);
SET
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Append (actual rows=67354 loops=1)
   ->  Hash Join (actual rows=22650 loops=1)
         Hash Cond: (range_partitioned_1.name = range_partitioned2_1.name)
         ->  Seq Scan on range_partition_less_j range_partitioned_1 (actual rows=34556 loops=1)
         ->  Hash (actual rows=34747 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 1836kB
               ->  Seq Scan on range_partition_less_j2 range_partitioned2_1 (actual rows=34747 loops=1)
   ->  Hash Join (actual rows=23608 loops=1)
         Hash Cond: (range_partitioned2_2.name = range_partitioned_2.name)
         ->  Seq Scan on range_partition_j_to_s2 range_partitioned2_2 (actual rows=34575 loops=1)
         ->  Hash (actual rows=34650 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 1832kB
               ->  Seq Scan on range_partition_j_to_s range_partitioned_2 (actual rows=34650 loops=1)
   ->  Hash Join (actual rows=21096 loops=1)
         Hash Cond: (range_partitioned2_3.name = range_partitioned_3.name)
         ->  Seq Scan on range_partition_s_greater2 range_partitioned2_3 (actual rows=30678 loops=1)
         ->  Hash (actual rows=30794 loops=1)
               Buckets: 32768  Batches: 1  Memory Usage: 1428kB
               ->  Seq Scan on range_partition_s_greater range_partitioned_3 (actual rows=30794 loops=1)
   ->  Nested Loop (actual rows=0 loops=1)
         ->  Seq Scan on range_partition_nulls2 range_partitioned2_4 (actual rows=0 loops=1)
         ->  Index Only Scan using range_partition_nulls_name_idx on range_partition_nulls range_partitioned_4 (never executed)
               Index Cond: (name = range_partitioned2_4.name)
               Heap Fetches: 0
```

## [Time-Based Partitioning]

### [Create Per-Month Partitions]

```sql
sample=# CREATE TABLE month_partitioned (day DATE, temperature NUMERIC(5,2)) PARTITION BY RANGE (day);
CREATE TABLE month_partition_2023_01 PARTITION OF month_partitioned FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE month_partition_2023_02 PARTITION OF month_partitioned FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
CREATE TABLE month_partition_2023_03 PARTITION OF month_partitioned FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');
CREATE TABLE month_partition_other PARTITION OF month_partitioned DEFAULT;
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
```

### [Populate Per-Month Partitions]

```sql
sample=# INSERT INTO month_partitioned SELECT( SELECT '2023-01-01'::date + floor(random() * ('2023-04-01'::date - '2023-01-01'::date) + b * 0)::integer),(SELECT floor(random() * 10000) / 100 + b * 0) FROM generate_series(1, 100000) AS a(b);
INSERT 0 100000
sample=# CREATE INDEX i_month_partitioned ON month_partitioned (day);
ANALYZE;
CREATE INDEX
ANALYZE
```

### [Random Partition Row]

```sql
sample=# WITH sample AS(    SELECT *, tableoid::regclass    FROM  month_partitioned ORDER BY random() LIMIT 5)SELECT * FROM sample ORDER BY 3, 1;
    day     | temperature |        tableoid
------------+-------------+-------------------------
 2023-01-04 |       68.35 | month_partition_2023_01
 2023-02-15 |       39.88 | month_partition_2023_02
 2023-02-16 |       22.17 | month_partition_2023_02
 2023-03-13 |       73.93 | month_partition_2023_03
 2023-03-17 |       72.15 | month_partition_2023_03
```

### [Partition Pruning]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF)  SELECT * FROM month_partitioned WHERE day = '2023-02-01';
                                        QUERY PLAN
------------------------------------------------------------------------------------------
 Bitmap Heap Scan on month_partition_2023_02 month_partitioned (actual rows=1149 loops=1)
   Recheck Cond: (day = '2023-02-01'::date)
   Heap Blocks: exact=169
   ->  Bitmap Index Scan on month_partition_2023_02_day_idx (actual rows=1149 loops=1)
         Index Cond: (day = '2023-02-01'::date)
```

### [Default Partition Usage]

```sql
sample=# INSERT INTO month_partitioned VALUES ('2023-05-01', 87.31);
INSERT 0 1
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM  month_partitioned WHERE day = '2023-05-01';
                                 QUERY PLAN
-----------------------------------------------------------------------------
 Seq Scan on month_partition_other month_partitioned (actual rows=1 loops=1)
   Filter: (day = '2023-05-01'::date)
```

### [Null Uses the DEFAULT Partition]

```sql
sample=# INSERT INTO month_partitioned VALUES (NULL, 46.24);
INSERT 0 1
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM  month_partitioned WHERE day IS NULL;
                                 QUERY PLAN
-----------------------------------------------------------------------------
 Seq Scan on month_partition_other month_partitioned (actual rows=1 loops=1)
   Filter: (day IS NULL)
   Rows Removed by Filter: 1
```

### [Attaching and Detaching Partitions]

```sql
sample=# ALTER TABLE month_partitioned DETACH PARTITION month_partition_other;
INSERT INTO month_partitioned VALUES (NULL, 46.24);
ALTER TABLE month_partitioned ATTACH PARTITION month_partition_other DEFAULT;
ALTER TABLE
ERROR:  行に対応するパーティションがリレーション"month_partitioned"に見つかりません
DETAIL:  失敗した行のパーティションキーは(day) = (null)を含みます。
ALTER TABLE
```

### [Pruning Using a STABLE Function]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM month_partitioned WHERE day = concat('''2023-02-01''' || '''''')::date;
                                            QUERY PLAN
--------------------------------------------------------------------------------------------------
 Append (actual rows=1149 loops=1)
   Subplans Removed: 3
   ->  Bitmap Heap Scan on month_partition_2023_02 month_partitioned_1 (actual rows=1149 loops=1)
         Recheck Cond: (day = (concat('''2023-02-01'''''''::text))::date)
         Heap Blocks: exact=169
         ->  Bitmap Index Scan on month_partition_2023_02_day_idx (actual rows=1149 loops=1)
               Index Cond: (day = (concat('''2023-02-01'''''''::text))::date)
```

### [Partition Expiration and Creation]

```sql
sample=# CREATE TABLE month_partition_2023_04 PARTITION OF month_partitioned FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
DROP TABLE month_partition_2023_01;
CREATE TABLE
DROP TABLE
```

### [Create Timestamp with Time Zone Partitions]

```sql
sample=# SET timezone = 'America/New_York';
sample=# CREATE TABLE month_ts_tz_partitioned (event_time TIMESTAMP WITH TIME ZONE, temperature NUMERIC(5,2)) PARTITION BY RANGE (event_time);
CREATE TABLE month_ts_tz_partition_2023_01 PARTITION OF month_ts_tz_partitioned FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');
CREATE TABLE month_ts_tz_partition_2023_02 PARTITION OF month_ts_tz_partitioned FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');
CREATE TABLE month_ts_tz_partition_2023_03 PARTITION OF month_ts_tz_partitioned FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');
CREATE TABLE month_ts_tz_partition_other PARTITION OF month_ts_tz_partitioned DEFAULT;
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
```

### [DATE Data Type Has No Time Zone]

```sql
sample=# SELECT EXTRACT(EPOCH FROM '2023-01-01'::date);
SELECT EXTRACT(EPOCH FROM '2023-01-01 00:00:00-00'::timestamptz);
SELECT EXTRACT(EPOCH FROM '2023-01-01'::timestamptz);
SELECT EXTRACT(EPOCH FROM '2023-01-01 00:00:00-05'::timestamptz);
  extract
------------
 1672531200


      extract
-------------------
 1672531200.000000


      extract
-------------------
 1672549200.000000


      extract
-------------------
 1672549200.000000
```

### [Populate Partitions]

```sql
sample=# INSERT INTO month_ts_tz_partitioned SELECT(    SELECT '2023-01-01 00:00:00'::timestamptz +       (floor(random() *              (extract(EPOCH FROM '2023-04-01'::timestamptz) -               extract(EPOCH FROM '2023-01-01'::timestamptz)) +              b * 0)::integer || 'seconds')::interval),(    SELECT floor(random() * 10000) / 100 + b * 0) FROM generate_series(1, 100000) AS a(b);
INSERT 0 100000
sample=# INSERT INTO month_ts_tz_partitioned VALUES ('2023-04-05 00:00:00', 50);
CREATE INDEX i_month_ts_tz_partitioned ON month_ts_tz_partitioned (event_time);
ANALYZE;
INSERT 0 1
CREATE INDEX
ANALYZE
```

### [Partition Details]

```sql
sample=# \d+ month_ts_tz_partitioned
                                パーティションテーブル"public.month_ts_tz_partitioned"
     列      |          タイプ          | 照合順序 | Null 値を許容 | デフォルト | ストレージ | 圧縮 | 統計目標 | 説明
-------------+--------------------------+----------+---------------+------------+------------+------+----------+------
 event_time  | timestamp with time zone |          |               |            | plain      |      |          |
 temperature | numeric(5,2)             |          |               |            | main       |      |          |
パーティションキー: RANGE (event_time)
インデックス:
    "i_month_ts_tz_partitioned" btree (event_time)
パーティション: month_ts_tz_partition_2023_01 FOR VALUES FROM ('2023-01-01 00:00:00-05') TO ('2023-02-01 00:00:00-05'),
                month_ts_tz_partition_2023_02 FOR VALUES FROM ('2023-02-01 00:00:00-05') TO ('2023-03-01 00:00:00-05'),
                month_ts_tz_partition_2023_03 FOR VALUES FROM ('2023-03-01 00:00:00-05') TO ('2023-04-01 00:00:00-04'),
                month_ts_tz_partition_other DEFAULT



```

### [First Partition Row]

```sql
sample=# SELECT CURRENT_TIMESTAMP;
       current_timestamp
-------------------------------
 2023-09-02 19:48:05.855111-04
sample=# SELECT *, tableoid::regclass FROM  month_ts_tz_partitioned ORDER BY 1 LIMIT 1;
       event_time       | temperature |           tableoid
------------------------+-------------+-------------------------------
 2023-01-01 00:00:24-05 |       15.74 | month_ts_tz_partition_2023_01
```

### [First Partition Row in a Different Time Zone]

```sql
sample=# SET timezone = 'Asia/Tokyo';
SELECT CURRENT_TIMESTAMP;
SELECT *, tableoid::regclass FROM  month_ts_tz_partitioned ORDER BY 1 LIMIT 1;
SET
       current_timestamp
-------------------------------
 2023-09-03 08:51:15.604735+09


       event_time       | temperature |           tableoid
------------------------+-------------+-------------------------------
 2023-01-01 14:00:24+09 |       15.74 | month_ts_tz_partition_2023_01
```

### [Partition Bounds Adjusted]

```sql
sample=# \d+ month_ts_tz_partitioned
                                パーティションテーブル"public.month_ts_tz_partitioned"
     列      |          タイプ          | 照合順序 | Null 値を許容 | デフォルト | ストレージ | 圧縮 | 統計目標 | 説明
-------------+--------------------------+----------+---------------+------------+------------+------+----------+------
 event_time  | timestamp with time zone |          |               |            | plain      |      |          |
 temperature | numeric(5,2)             |          |               |            | main       |      |          |
パーティションキー: RANGE (event_time)
インデックス:
    "i_month_ts_tz_partitioned" btree (event_time)
パーティション: month_ts_tz_partition_2023_01 FOR VALUES FROM ('2023-01-01 14:00:00+09') TO ('2023-02-01 14:00:00+09'),
                month_ts_tz_partition_2023_02 FOR VALUES FROM ('2023-02-01 14:00:00+09') TO ('2023-03-01 14:00:00+09'),
                month_ts_tz_partition_2023_03 FOR VALUES FROM ('2023-03-01 14:00:00+09') TO ('2023-04-01 13:00:00+09'),
                month_ts_tz_partition_other DEFAULT
```

### [The Same in UTC]

```sql
sample=# SET timezone = 'UTC';
SELECT *, tableoid::regclass FROM  month_ts_tz_partitioned ORDER BY 1 LIMIT 1;
SET
       event_time       | temperature |           tableoid
------------------------+-------------+-------------------------------
 2023-01-01 05:00:24+00 |       15.74 | month_ts_tz_partition_2023_01
sample=# \d+ month_ts_tz_partitioned
                                パーティションテーブル"public.month_ts_tz_partitioned"
     列      |          タイプ          | 照合順序 | Null 値を許容 | デフォルト | ストレージ | 圧縮 | 統計目標 | 説明
-------------+--------------------------+----------+---------------+------------+------------+------+----------+------
 event_time  | timestamp with time zone |          |               |            | plain      |      |          |
 temperature | numeric(5,2)             |          |               |            | main       |      |          |
パーティションキー: RANGE (event_time)
インデックス:
    "i_month_ts_tz_partitioned" btree (event_time)
パーティション: month_ts_tz_partition_2023_01 FOR VALUES FROM ('2023-01-01 05:00:00+00') TO ('2023-02-01 05:00:00+00'),
                month_ts_tz_partition_2023_02 FOR VALUES FROM ('2023-02-01 05:00:00+00') TO ('2023-03-01 05:00:00+00'),
                month_ts_tz_partition_2023_03 FOR VALUES FROM ('2023-03-01 05:00:00+00') TO ('2023-04-01 04:00:00+00'),
                month_ts_tz_partition_other DEFAULT
```

### [No Pruning of a Function Call on a Column]

```sql
sample=# SET timezone = 'America/New_York';
SET
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM month_ts_tz_partitioned WHERE date(event_time) = '2023-02-05';
                                              QUERY PLAN
------------------------------------------------------------------------------------------------------
 Append (actual rows=1113 loops=1)
   ->  Seq Scan on month_ts_tz_partition_2023_01 month_ts_tz_partitioned_1 (actual rows=0 loops=1)
         Filter: (date(event_time) = '2023-02-05'::date)
         Rows Removed by Filter: 34399
   ->  Seq Scan on month_ts_tz_partition_2023_02 month_ts_tz_partitioned_2 (actual rows=1113 loops=1)
         Filter: (date(event_time) = '2023-02-05'::date)
         Rows Removed by Filter: 30184
   ->  Seq Scan on month_ts_tz_partition_2023_03 month_ts_tz_partitioned_3 (actual rows=0 loops=1)
         Filter: (date(event_time) = '2023-02-05'::date)
         Rows Removed by Filter: 34304
   ->  Seq Scan on month_ts_tz_partition_other month_ts_tz_partitioned_4 (actual rows=0 loops=1)
         Filter: (date(event_time) = '2023-02-05'::date)
         Rows Removed by Filter: 1
```

### [Date Range Can Be Pruned]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM month_ts_tz_partitioned WHERE event_time >= '2023-02-05' AND      event_time <  '2023-02-06';
                                                                           QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on month_ts_tz_partition_2023_02 month_ts_tz_partitioned (actual rows=1113 loops=1)
   Recheck Cond: ((event_time >= '2023-02-05 00:00:00-05'::timestamp with time zone) AND (event_time < '2023-02-06 00:00:00-05'::timestamp with time zone))
   Heap Blocks: exact=170
   ->  Bitmap Index Scan on month_ts_tz_partition_2023_02_event_time_idx (actual rows=1113 loops=1)
         Index Cond: ((event_time >= '2023-02-05 00:00:00-05'::timestamp with time zone) AND (event_time < '2023-02-06 00:00:00-05'::timestamp with time zone))
```

### [Date Calculation Can Be Pruned]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT  * FROM month_ts_tz_partitioned WHERE event_time > concat('''2023-02-05 23:43:51''' || '''''')::timestamptz - '24 hours'::interval AND      event_time <= concat('''2023-02-05 23:43:51''' || '''''')::timestamptz;
                                                                                                               QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Append (actual rows=1123 loops=1)
   Subplans Removed: 3
   ->  Bitmap Heap Scan on month_ts_tz_partition_2023_02 month_ts_tz_partitioned_1 (actual rows=1123 loops=1)
         Recheck Cond: ((event_time > ((concat('''2023-02-05 23:43:51'''''''::text))::timestamp with time zone - '24:00:00'::interval)) AND (event_time <= (concat('''2023-02-05 23:43:51'''''''::text))::timestamp with time zone))
         Heap Blocks: exact=170
         ->  Bitmap Index Scan on month_ts_tz_partition_2023_02_event_time_idx (actual rows=1123 loops=1)
               Index Cond: ((event_time > ((concat('''2023-02-05 23:43:51'''''''::text))::timestamp with time zone - '24:00:00'::interval)) AND (event_time <= (concat('''2023-02-05 23:43:51'''''''::text))::timestamp with time zone))

```

### [Timestamp Range Can Be Pruned]

```sql
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00';
                                                                           QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on month_ts_tz_partition_2023_03 month_ts_tz_partitioned (actual rows=1047 loops=1)
   Recheck Cond: ((event_time >= '2023-03-01 00:00:00-05'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00-05'::timestamp with time zone))
   Heap Blocks: exact=186
   ->  Bitmap Index Scan on month_ts_tz_partition_2023_03_event_time_idx (actual rows=1047 loops=1)
         Index Cond: ((event_time >= '2023-03-01 00:00:00-05'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00-05'::timestamp with time zone))
```

### [Where Are Per-Day Rows?]

```sql
sample=# SELECT COUNT(*) FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00';
 count
-------
  1047
```

### [Where Are Per-Day Rows?]

```sql
sample=# SELECT *, tableoid::regclass FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00'ORDER BY 1 LIMIT 1;
SELECT *, tableoid::regclass FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00' ORDER BY 1 DESC LIMIT 1;
       event_time       | temperature |           tableoid
------------------------+-------------+-------------------------------
 2023-03-01 00:00:08-05 |       75.50 | month_ts_tz_partition_2023_03


       event_time       | temperature |           tableoid
------------------------+-------------+-------------------------------
 2023-03-01 23:57:14-05 |       84.63 | month_ts_tz_partition_2023_03
```

### [Query in a Different Time Zone]

```sql
sample=# SET timezone = 'Asia/Tokyo';
SET
sample=# EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF) SELECT * FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00';
                                                                              QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Append (actual rows=1065 loops=1)
   ->  Bitmap Heap Scan on month_ts_tz_partition_2023_02 month_ts_tz_partitioned_1 (actual rows=638 loops=1)
         Recheck Cond: ((event_time >= '2023-03-01 00:00:00+09'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00+09'::timestamp with time zone))
         Heap Blocks: exact=163
         ->  Bitmap Index Scan on month_ts_tz_partition_2023_02_event_time_idx (actual rows=638 loops=1)
               Index Cond: ((event_time >= '2023-03-01 00:00:00+09'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00+09'::timestamp with time zone))
   ->  Bitmap Heap Scan on month_ts_tz_partition_2023_03 month_ts_tz_partitioned_2 (actual rows=427 loops=1)
         Recheck Cond: ((event_time >= '2023-03-01 00:00:00+09'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00+09'::timestamp with time zone))
         Heap Blocks: exact=167
         ->  Bitmap Index Scan on month_ts_tz_partition_2023_03_event_time_idx (actual rows=427 loops=1)
               Index Cond: ((event_time >= '2023-03-01 00:00:00+09'::timestamp with time zone) AND (event_time < '2023-03-02 00:00:00+09'::timestamp with time zone))
```

### [Different Count]

```sql
sample=# SELECT COUNT(*) FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00';
 count
-------
  1065
```

### [Partition Range]

```sql
sample=# SELECT *, tableoid::regclass FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00' ORDER BY 1 LIMIT 1;
SELECT *, tableoid::regclass FROM month_ts_tz_partitioned WHERE event_time >= '2023-03-01 00:00:00' AND      event_time <  '2023-03-02 00:00:00'ORDER BY 1 DESC LIMIT 1;
       event_time       | temperature |           tableoid
------------------------+-------------+-------------------------------
 2023-03-01 00:00:51+09 |        2.04 | month_ts_tz_partition_2023_02


       event_time       | temperature |           tableoid
------------------------+-------------+-------------------------------
 2023-03-01 23:59:49+09 |       92.30 | month_ts_tz_partition_2023_03
```

### [Range Boundaries Are Set at Creation]

```sql
sample=# CREATE TABLE month_ts_tz_partition_2023_04 PARTITION OF month_ts_tz_partitioned FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
ERROR:  パーティション"month_ts_tz_partition_2023_04"はパーティション"month_ts_tz_partition_2023_03"と重複があります
行 1: ...ITION OF month_ts_tz_partitioned FOR VALUES FROM ('2023-04-0...
```

### [Matching Rows in the DEFAULT Partition]

```sql
sample=# SET timezone = 'America/New_York';
CREATE TABLE month_ts_tz_partition_2023_04 PARTITION OF month_ts_tz_partitioned FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
SET
ERROR:  デフォルトパーティション"month_ts_tz_partition_other"の一部の行が更新後のパーティション制約に違反しています
```

### [Move DEFAULT Rows to a New Partition]

```sql
sample=# BEGIN WORK;
CREATE TEMP TABLE tmp_default AS SELECT * FROM month_ts_tz_partition_other WHERE event_time >= '2023-04-01 00:00:00' AND event_time <  '2023-05-01 00:00:00';
DELETE FROM month_ts_tz_partition_other WHERE event_time >= '2023-04-01 00:00:00' AND event_time <  '2023-05-01 00:00:00';
CREATE TABLE month_ts_tz_partition_2023_04 PARTITION OF month_ts_tz_partitioned FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');
INSERT INTO month_ts_tz_partitioned SELECT * FROM tmp_default;
SELECT * FROM  month_ts_tz_partition_other;
COMMIT;
BEGIN
SELECT 1
DELETE 1
CREATE TABLE
INSERT 0 1
 event_time | temperature
------------+-------------


COMMIT
```

### [New Partition Contents]

```sql
sample=# SELECT * FROM  month_ts_tz_partition_2023_04;
SELECT * FROM  month_ts_tz_partition_other;
       event_time       | temperature
------------------------+-------------
 2023-04-05 00:00:00-04 |       50.00


 event_time | temperature
------------+-------------
```

## [Row Migration]

### [Rows in ’j’ to ’s’ Partition]

```sql
sample=# SELECT *, tableoid::regclass FROM range_partitioned WHERE name = 'Ma' ORDER BY 2, 1;
 name |        tableoid
------+------------------------
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
 Ma   | range_partition_j_to_s
```

### [Migration to Greater than ’s’ Partition]

```sql
sample=# UPDATE range_partitioned SET name = 'zz_' || name WHERE name = 'Ma';
SELECT *, tableoid::regclass FROM range_partitioned WHERE name = 'zz_Ma' ORDER BY 2, 1;
UPDATE 15
 name  |         tableoid
-------+---------------------------
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
 zz_Ma | range_partition_s_greater
```

### [psql support]

```sql
sample=# COMMENT ON TABLE range_partitioned IS 'Section 2';
COMMENT ON TABLE hash_partitioned IS 'Section 2';
COMMENT ON TABLE list_partitioned IS 'Section 2';
COMMENT ON TABLE range_partitioned2 IS 'Section 4';
COMMENT ON TABLE month_partitioned IS 'Section 5';
COMMENT ON TABLE month_ts_tz_partitioned IS 'Section 5';
\dPt+
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
                        パーティションテーブルの一覧
 スキーマ |          名前           |  所有者  | トータルサイズ |   説明
----------+-------------------------+----------+----------------+-----------
 public   | hash_partitioned        | postgres | 3904 kB        | Section 2
 public   | list_partitioned        | postgres | 4304 kB        | Section 2
 public   | month_partitioned       | postgres | 2904 kB        | Section 5
 public   | month_ts_tz_partitioned | postgres | 4448 kB        | Section 5
 public   | range_partitioned       | postgres | 3928 kB        | Section 2
 public   | range_partitioned2      | postgres | 3920 kB        | Section 4
```
