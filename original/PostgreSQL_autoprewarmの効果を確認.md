# autoprewarm の効果を確認

postgresql.conf の設定を書き換えて、サービスを再起動します

```
sample=# show shared_preload_libraries;
 shared_preload_libraries
--------------------------
 pg_prewarm
(1 row)
```

データベース作成

```
postgres@masami-L ~> createdb -U postgres sample
postgres@masami-L ~> psql -U postgres -d sample
psql (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
Type "help" for help.
```

キャッシュ状況を確認するために、pg_buffercache 拡張をインストールします

```sql
sample=# create extension pg_buffercache;
CREATE EXTENSION
sample=# create extension pg_prewarm;
CREATE EXTENSION
```

キャッシュ状況を確認します

```sql
sample=# SELECT
    C.relname
    ,count(*) AS buffers
FROM
    pg_buffercache B
INNER JOIN pg_class C
    ON b.relfilenode = pg_relation_filenode(c.oid)
    AND
    b.reldatabase IN (
        0
        ,(
            SELECT oid
            FROM pg_database
            WHERE datname = current_database()
        )
    )
GROUP BY C.relname
ORDER BY 2 DESC limit 5
;
          relname          | buffers
---------------------------+---------
 pg_class                  |      17
 pg_depend_reference_index |      14
 pg_attribute              |      14
 pg_proc                   |      12
 pg_depend                 |      12
(5 rows)
```

pgbench を動かしてみます

```
postgres@masami-L ~> pgbench -i -s 10 -d sample
dropping old tables...
creating tables...
generating data (client-side)...
1000000 of 1000000 tuples (100%) done (elapsed 1.45 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 2.39 s (drop tables 0.01 s, create tables 0.01 s, client-side generate 1.52 s, vacuum 0.32 s, primary keys 0.52 s).
postgres@masami-L ~> pgbench -c 1 -T 1000 -d sample
```

キャッシュの状況確認

```sql
postgres@masami-L ~> psql -U postgres -d sample
psql (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
Type "help" for help.

sample=# SELECT
    C.relname
    ,count(*) AS buffers
FROM
    pg_buffercache B
INNER JOIN pg_class C
    ON b.relfilenode = pg_relation_filenode(c.oid)
    AND
    b.reldatabase IN (
        0
        ,(
            SELECT oid
            FROM pg_database
            WHERE datname = current_database()
        )
    )
GROUP BY C.relname
ORDER BY 2 DESC limit 5
;
        relname        | buffers
-----------------------+---------
 pgbench_accounts      |    1680
 pgbench_accounts_pkey |     276
 pgbench_history       |     181
 pg_attribute          |      32
 pg_class              |      17
(5 rows)
```

クエリを２回実行します

```sql
sample=# \timing
Timing is on.
sample=# explain SELECT * FROM pgbench_accounts JOIN pgbench_branches USING (bid) JOIN pgbench_tellers USING (bid);
                                        QUERY PLAN
-------------------------------------------------------------------------------------------
 Hash Join  (cost=4.85..141398.85 rows=10000000 width=805)
   Hash Cond: (pgbench_accounts.bid = pgbench_branches.bid)
   ->  Seq Scan on pgbench_accounts  (cost=0.00..26394.00 rows=1000000 width=97)
   ->  Hash  (cost=3.60..3.60 rows=100 width=716)
         ->  Hash Join  (cost=1.23..3.60 rows=100 width=716)
               Hash Cond: (pgbench_tellers.bid = pgbench_branches.bid)
               ->  Seq Scan on pgbench_tellers  (cost=0.00..2.00 rows=100 width=352)
               ->  Hash  (cost=1.10..1.10 rows=10 width=364)
                     ->  Seq Scan on pgbench_branches  (cost=0.00..1.10 rows=10 width=364)
 JIT:
   Functions: 20
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(12 rows)

Time: 286.143 ms
sample=# explain SELECT * FROM pgbench_accounts JOIN pgbench_branches USING (bid) JOIN pgbench_tellers USING (bid);
                                        QUERY PLAN
-------------------------------------------------------------------------------------------
 Hash Join  (cost=4.85..141398.85 rows=10000000 width=805)
   Hash Cond: (pgbench_accounts.bid = pgbench_branches.bid)
   ->  Seq Scan on pgbench_accounts  (cost=0.00..26394.00 rows=1000000 width=97)
   ->  Hash  (cost=3.60..3.60 rows=100 width=716)
         ->  Hash Join  (cost=1.23..3.60 rows=100 width=716)
               Hash Cond: (pgbench_tellers.bid = pgbench_branches.bid)
               ->  Seq Scan on pgbench_tellers  (cost=0.00..2.00 rows=100 width=352)
               ->  Hash  (cost=1.10..1.10 rows=10 width=364)
                     ->  Seq Scan on pgbench_branches  (cost=0.00..1.10 rows=10 width=364)
 JIT:
   Functions: 20
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(12 rows)

Time: 2.793 ms
```

1 回目は 286ms ２回目のクエリは 3ms でした  
サービス再起動前に hotstanby の準備をします

```sql
sample=# select pg_prewarm('pgbench_accounts', 'buffer');
 pg_prewarm
------------
      16394
(1 row)

Time: 151.783 ms
sample=# select pg_prewarm('pgbench_branches', 'buffer');
 pg_prewarm
------------
          1
(1 row)

Time: 0.412 ms
sample=# select pg_prewarm('pgbench_tellers', 'buffer');
 pg_prewarm
------------
          1
(1 row)

Time: 0.390 ms
```

サービスを再起動して、autoprewarm の効果を確認します

```sql
sample=# explain SELECT * FROM pgbench_accounts JOIN pgbench_branches USING (bid) JOIN pgbench_tellers USING (bid);
                                        QUERY PLAN
-------------------------------------------------------------------------------------------
 Hash Join  (cost=4.85..141398.85 rows=10000000 width=805)
   Hash Cond: (pgbench_accounts.bid = pgbench_branches.bid)
   ->  Seq Scan on pgbench_accounts  (cost=0.00..26394.00 rows=1000000 width=97)
   ->  Hash  (cost=3.60..3.60 rows=100 width=716)
         ->  Hash Join  (cost=1.23..3.60 rows=100 width=716)
               Hash Cond: (pgbench_tellers.bid = pgbench_branches.bid)
               ->  Seq Scan on pgbench_tellers  (cost=0.00..2.00 rows=100 width=352)
               ->  Hash  (cost=1.10..1.10 rows=10 width=364)
                     ->  Seq Scan on pgbench_branches  (cost=0.00..1.10 rows=10 width=364)
 JIT:
   Functions: 20
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(12 rows)

Time: 28.950 ms
sample=# explain SELECT * FROM pgbench_accounts JOIN pgbench_branches USING (bid) JOIN pgbench_tellers USING (bid);
                                        QUERY PLAN
-------------------------------------------------------------------------------------------
 Hash Join  (cost=4.85..141398.85 rows=10000000 width=805)
   Hash Cond: (pgbench_accounts.bid = pgbench_branches.bid)
   ->  Seq Scan on pgbench_accounts  (cost=0.00..26394.00 rows=1000000 width=97)
   ->  Hash  (cost=3.60..3.60 rows=100 width=716)
         ->  Hash Join  (cost=1.23..3.60 rows=100 width=716)
               Hash Cond: (pgbench_tellers.bid = pgbench_branches.bid)
               ->  Seq Scan on pgbench_tellers  (cost=0.00..2.00 rows=100 width=352)
               ->  Hash  (cost=1.10..1.10 rows=10 width=364)
                     ->  Seq Scan on pgbench_branches  (cost=0.00..1.10 rows=10 width=364)
 JIT:
   Functions: 20
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(12 rows)

Time: 3.506 ms
```

再起動前の速度ではないにしても、１０倍以上の速度になりました。

```Sql
sample=# SELECT
    C.relname
    ,count(*) AS buffers
FROM
    pg_buffercache B
INNER JOIN pg_class C
    ON b.relfilenode = pg_relation_filenode(c.oid)
    AND
    b.reldatabase IN (
        0
        ,(
            SELECT oid
            FROM pg_database
            WHERE datname = current_database()
        )
    )
GROUP BY C.relname
ORDER BY 2 DESC limit 5
;
             relname             | buffers
---------------------------------+---------
 pgbench_accounts                |   16075
 pg_attribute                    |      29
 pg_class                        |      13
 pg_attribute_relid_attnum_index |       8
 pg_proc                         |       8
(5 rows)

Time: 37.529 ms
```

キャッシュの設定を見直せばもうちょい早くなるかもしれません。

OS 再起動後はキャッシュクリアされているため、速度は元に戻ります

```Sql
sample=# \timing
Timing is on.
sample=# explain SELECT * FROM pgbench_accounts JOIN pgbench_branches USING (bid) JOIN pgbench_tellers USING (bid);
                                        QUERY PLAN
-------------------------------------------------------------------------------------------
 Hash Join  (cost=4.85..141398.85 rows=10000000 width=805)
   Hash Cond: (pgbench_accounts.bid = pgbench_branches.bid)
   ->  Seq Scan on pgbench_accounts  (cost=0.00..26394.00 rows=1000000 width=97)
   ->  Hash  (cost=3.60..3.60 rows=100 width=716)
         ->  Hash Join  (cost=1.23..3.60 rows=100 width=716)
               Hash Cond: (pgbench_tellers.bid = pgbench_branches.bid)
               ->  Seq Scan on pgbench_tellers  (cost=0.00..2.00 rows=100 width=352)
               ->  Hash  (cost=1.10..1.10 rows=10 width=364)
                     ->  Seq Scan on pgbench_branches  (cost=0.00..1.10 rows=10 width=364)
 JIT:
   Functions: 20
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(12 rows)

Time: 296.343 ms
```
