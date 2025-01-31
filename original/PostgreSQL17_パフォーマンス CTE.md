https://www.pgedge.com/blog/postgresql-17-a-major-step-forward-in-performance-logical-replication-and-more

まずは PostgreSQL 16 で実行

```
createdb -U postgres experiment
```

```sql
experiment=# create table t1(a int);
CREATE TABLE
experiment=# create table t2(b int);
CREATE TABLE
experiment=# create index my_index on t1 using btree (a);
CREATE INDEX
experiment=# insert into t1 select generate_series(1, 100000) from generate_series(1, 3);
INSERT 0 300000
experiment=# insert into t2 select generate_series(1, 100) from generate_series(1, 10);
INSERT 0 1000
experiment=# analyze t1;
ANALYZE
experiment=# analyze t2;
ANALYZE

experiment=# explain analyze with my_cte as materialized (select b from t2)
experiment-# select * from t1 where t1.a in (select b from my_cte);
                                                        QUERY PLAN

--------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=37.92..337.40 rows=3040 width=4) (actual time=1.292..1.528 rows=300 loops=1)
   CTE my_cte
     ->  Seq Scan on t2  (cost=0.00..15.00 rows=1000 width=4) (actual time=0.029..0.122 rows=1000 loops=1)
   ->  HashAggregate  (cost=22.50..24.50 rows=200 width=4) (actual time=0.505..0.528 rows=100 loops=1)
         Group Key: my_cte.b
         Batches: 1  Memory Usage: 40kB
         ->  CTE Scan on my_cte  (cost=0.00..20.00 rows=1000 width=4) (actual time=0.032..0.302 rows=1000 loops=1)
   ->  Index Only Scan using my_index on t1  (cost=0.42..1.46 rows=3 width=4) (actual time=0.009..0.010 rows=3 loops=100)
         Index Cond: (a = my_cte.b)
         Heap Fetches: 0
 Planning Time: 2.286 ms
 Execution Time: 2.892 ms
(12 行)
```

PostgreSQL17 で同じクエリを実行します

```sql
sample=# explain analyze with my_cte as materialized (select b from t2)
sample-# select * from t1 where t1.a in (select b from my_cte);
                                                            QUERY PLAN

-----------------------------------------------------------------------------------------------------------------------------------
 Merge Join  (cost=42.24..59.14 rows=305 width=4) (actual time=0.508..0.699 rows=300 loops=1)
   Merge Cond: (t1.a = my_cte.b)
   CTE my_cte
     ->  Seq Scan on t2  (cost=0.00..15.00 rows=1000 width=4) (actual time=0.022..0.108 rows=1000 loops=1)
   ->  Index Only Scan using my_index on t1  (cost=0.42..12684.90 rows=300000 width=4) (actual time=0.022..0.146 rows=301 loops=1)
         Heap Fetches: 301
   ->  Sort  (cost=26.82..27.07 rows=100 width=4) (actual time=0.482..0.489 rows=100 loops=1)
         Sort Key: my_cte.b
         Sort Method: quicksort  Memory: 25kB
         ->  HashAggregate  (cost=22.50..23.50 rows=100 width=4) (actual time=0.447..0.459 rows=100 loops=1)
               Group Key: my_cte.b
               Batches: 1  Memory Usage: 24kB
               ->  CTE Scan on my_cte  (cost=0.00..20.00 rows=1000 width=4) (actual time=0.024..0.259 rows=1000 loops=1) Planning Time: 4.902 ms
 Execution Time: 2.071 ms
(15 行)
```

Postgres 17 のクエリ プランを見るとわかるように、サブクエリからの列統計は、外部クエリの上位プランナーに正しく伝播しています。これにより、PostgreSQL はクエリの実行時間を改善するより適切なプランを選択できるようになります。
