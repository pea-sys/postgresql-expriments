# enable_memoize によるネストされたループ結合のパフォーマンス向上

次のブログのトレースです

https://blog.jooq.org/postgresql-14s-enable_memoize-for-improved-performance-of-nested-loop-joins/

### `enable_memoize`を切り替える

PostgreSQL 14 に新たに追加された `enable_memonize`によるパフォーマンス向上に関する記事です

データベース作成

```
postgres@masami-L ~> createdb -U postgres sample
postgres@masami-L ~> psql -U postgres -d sample
psql (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
Type "help" for help.

sample=#
```

テーブル作成

挿入データは次のようになっています

- テーブル t とテーブル u の両方に 100000 行があります。
- t.j は 1~5 が各 20000 回出現します。
- u.j には 1~20000 が各 5 回出現します。

```Sql
sample=# CREATE TABLE t AS
SELECT i, i % 5 AS j
FROM generate_series(1, 100000) AS t(i);

CREATE TABLE u AS
SELECT i, i % 20000 as j
FROM generate_series(1, 100000) AS t(i);

CREATE INDEX uj ON u(j);
SELECT 100000
SELECT 100000
CREATE INDEX
```

postgresql14 で追加された`enable_memoize`はデフォルトで有効です

```sql
sample=# SELECT current_setting('enable_memoize');
 current_setting
-----------------
 on
(1 row)
```

実行計画を確認

```sql
sample=# EXPLAIN
SELECT *
FROM t JOIN u ON t.j = u.j;
                               QUERY PLAN
------------------------------------------------------------------------
 Nested Loop  (cost=0.30..8945.41 rows=502968 width=16)
   ->  Seq Scan on t  (cost=0.00..1443.00 rows=100000 width=8)
   ->  Memoize  (cost=0.30..0.41 rows=5 width=8)
         Cache Key: t.j
         Cache Mode: logical
         ->  Index Scan using uj on u  (cost=0.29..0.40 rows=5 width=8)
               Index Cond: (j = t.j)
(7 rows)
```

t は一度シーケンシャルスキャンされた後はメモ化され、5 つの行しか取り扱っていません。

`enable_memoize`を OFF にしてみます

```Sql
sample=# SET enable_memoize = OFF;
SET
sample=# EXPLAIN
SELECT *
FROM t JOIN u ON t.j = u.j;
                             QUERY PLAN
---------------------------------------------------------------------
 Hash Join  (cost=3084.00..11604.68 rows=502968 width=16)
   Hash Cond: (t.j = u.j)
   ->  Seq Scan on t  (cost=0.00..1443.00 rows=100000 width=8)
   ->  Hash  (cost=1443.00..1443.00 rows=100000 width=8)
         ->  Seq Scan on u  (cost=0.00..1443.00 rows=100000 width=8)
(5 rows)
```

ハッシュ結合されるようになりました

### ベンチマーク

```sql
sample=# DO $$
DECLARE
  v_ts TIMESTAMP;
  v_repeat CONSTANT INT := 25;
  rec RECORD;
BEGIN

  -- Repeat the whole benchmark several times to avoid warmup penalty
  FOR r IN 1..5 LOOP
    v_ts := clock_timestamp();
    SET enable_memoize = OFF;

    FOR i IN 1..v_repeat LOOP
      FOR rec IN (
        SELECT t.*
        FROM t JOIN u ON t.j = u.j
      ) LOOP
        NULL;
      END LOOP;
    END LOOP;

    RAISE INFO 'Run %, Statement 1: %', r, (clock_timestamp() - v_ts);
    v_ts := clock_timestamp();
    SET enable_memoize = ON;

    FOR i IN 1..v_repeat LOOP
      FOR rec IN (
        SELECT t.*
        FROM t JOIN u ON t.j = u.j
      ) LOOP
        NULL;
      END LOOP;
END$$;LOOP;NFO '';n %, Statement 2: %', r, (clock_timestamp() - v_ts);
INFO:  Run 1, Statement 1: 00:00:07.124862
INFO:  Run 1, Statement 2: 00:00:06.100099
INFO:
INFO:  Run 2, Statement 1: 00:00:07.069126
INFO:  Run 2, Statement 2: 00:00:06.096658
INFO:
INFO:  Run 3, Statement 1: 00:00:07.060123
INFO:  Run 3, Statement 2: 00:00:06.110259
INFO:
INFO:  Run 4, Statement 1: 00:00:07.052065
INFO:  Run 4, Statement 2: 00:00:06.106323
INFO:
INFO:  Run 5, Statement 1: 00:00:07.05908
INFO:  Run 5, Statement 2: 00:00:06.102934
INFO:
DO
```

一貫して`enable_memoize = ON`の方が速いです

### LATERAL の最適化

```sql
sample=# EXPLAIN SELECT *
FROM
  t,
  LATERAL (
    SELECT count(*)
    FROM u
    WHERE t.j = u.j
  ) AS u(j)
;
                                    QUERY PLAN
-----------------------------------------------------------------------------------
 Nested Loop  (cost=4.40..3969.47 rows=100000 width=16)
   ->  Seq Scan on t  (cost=0.00..1443.00 rows=100000 width=8)
   ->  Memoize  (cost=4.40..4.42 rows=1 width=8)
         Cache Key: t.j
         Cache Mode: binary
         ->  Aggregate  (cost=4.39..4.40 rows=1 width=8)
               ->  Index Only Scan using uj on u  (cost=0.29..4.38 rows=5 width=0)
                     Index Cond: (j = t.j)
(8 rows)
```

ベンチマーク

```sql
sample=# DO $$
DECLARE
  v_ts TIMESTAMP;
  v_repeat CONSTANT INT := 25;
  rec RECORD;
BEGIN

  -- Repeat the whole benchmark several times to avoid warmup penalty
  FOR r IN 1..5 LOOP
    v_ts := clock_timestamp();
    SET enable_memoize = OFF;

    FOR i IN 1..v_repeat LOOP
      FOR rec IN (
        SELECT *
        FROM
          t,
          LATERAL (
            SELECT count(*)
            FROM u
            WHERE t.j = u.j
          ) AS u(j)
      ) LOOP
        NULL;
      END LOOP;
    END LOOP;

    RAISE INFO 'Run %, Statement 1: %', r, (clock_timestamp() - v_ts);
    v_ts := clock_timestamp();
    SET enable_memoize = ON;

    FOR i IN 1..v_repeat LOOP
END$$;LOOP;NFO '';n %, Statement 2: %', r, (clock_timestamp() - v_ts);
INFO:  Run 1, Statement 1: 00:00:06.890307
INFO:  Run 1, Statement 2: 00:00:01.923424
INFO:
INFO:  Run 2, Statement 1: 00:00:06.595854
INFO:  Run 2, Statement 2: 00:00:01.919769
INFO:
INFO:  Run 3, Statement 1: 00:00:06.58763
INFO:  Run 3, Statement 2: 00:00:01.915533
INFO:
INFO:  Run 4, Statement 1: 00:00:06.626223
INFO:  Run 4, Statement 2: 00:00:01.919663
INFO:
INFO:  Run 5, Statement 1: 00:00:06.598454
INFO:  Run 5, Statement 2: 00:00:01.923146
INFO:
DO
```

LATERAL は通常の相関サブクエリには使用できるのでしょうか？

```sql
sample=# EXPLAIN SELECT
  t.*,
  (
    SELECT count(*)
    FROM u
    WHERE t.j = u.j
  ) j
FROM t;
                                   QUERY PLAN
---------------------------------------------------------------------------------
 Seq Scan on t  (cost=0.00..441693.00 rows=100000 width=16)
   SubPlan 1
     ->  Aggregate  (cost=4.39..4.40 rows=1 width=8)
           ->  Index Only Scan using uj on u  (cost=0.29..4.38 rows=5 width=0)
                 Index Cond: (j = t.j)
 JIT:
   Functions: 7
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(8 rows)
```

実行計画を見る限りではだめでそうですが、ベンチマークをとります

```sql
sample=# DO $$
DECLARE
  v_ts TIMESTAMP;
  v_repeat CONSTANT INT := 25;
  rec RECORD;
BEGIN

  -- Repeat the whole benchmark several times to avoid warmup penalty
  FOR r IN 1..5 LOOP
    v_ts := clock_timestamp();
    SET enable_memoize = OFF;

    FOR i IN 1..v_repeat LOOP
      FOR rec IN (
        SELECT
        t.*,
        (
            SELECT count(*)
            FROM u
            WHERE t.j = u.j
        ) j
        FROM t
      ) LOOP
        NULL;
      END LOOP;
    END LOOP;

    RAISE INFO 'Run %, Statement 1: %', r, (clock_timestamp() - v_ts);
    v_ts := clock_timestamp();
    SET enable_memoize = ON;

    FOR i IN 1..v_repeat LOOP
END$$;LOOP;NFO '';n %, Statement 2: %', r, (clock_timestamp() - v_ts);
INFO:  Run 1, Statement 1: 00:00:06.893658
INFO:  Run 1, Statement 2: 00:00:06.897006
INFO:
INFO:  Run 2, Statement 1: 00:00:06.900755
INFO:  Run 2, Statement 2: 00:00:06.892166
INFO:
INFO:  Run 3, Statement 1: 00:00:06.896888
INFO:  Run 3, Statement 2: 00:00:06.898992
INFO:
INFO:  Run 4, Statement 1: 00:00:06.914074
INFO:  Run 4, Statement 2: 00:00:06.901005
INFO:
INFO:  Run 5, Statement 1: 00:00:06.902146
INFO:  Run 5, Statement 2: 00:00:06.876741
INFO:
DO
```
