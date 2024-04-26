# GROUP BY の最適化

次ｍのページにある GROUP BY の小さな最適化を試します

https://www.cybertec-postgresql.com/en/speeding-up-group-by-in-postgresql/

DB の作成

```
createdb -U postgres sample
psql -U postgres -d sample
```

データの作成

```sql
sample=# create table t_agg (x int, y int, z numeric);
CREATE TABLE
sample=# insert into t_agg select id % 2, id % 10000, random() from generate_series(1, 10000000) as id;
INSERT 0 10000000
sample=# vacuum analyze;
VACUUM
```

実行計画の視認性を上げるために並行クエリを off にします

```sql
sample=# set max_parallel_workers_per_gather to 0;
SET
```

GROUP BY(x -> y)の実行

```sql
sample=# explain analyze select x, y, avg(z) from t_agg group by 1,2;
                                                         QUERY PLAN

----------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=238697.01..238947.86 rows=20068 width=40) (actual time=5686.836..5695.259 rows=10000 loops=1)
   Group Key: x, y
   Batches: 1  Memory Usage: 4881kB
   ->  Seq Scan on t_agg  (cost=0.00..163696.15 rows=10000115 width=19) (actual time=0.505..1001.261 rows=10000000 loops=1)
 Planning Time: 5.708 ms
 Execution Time: 5698.786 ms
(6 行)
```

GROUP BY(y -> x)の実行

```sql
sample=# explain analyze select x, y, avg(z) from t_agg group by 2,1;
                                                        QUERY PLAN

---------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=238697.01..238947.86 rows=20068 width=40) (actual time=4567.695..4574.348 rows=10000 loops=1)
   Group Key: y, x
   Batches: 1  Memory Usage: 4881kB
   ->  Seq Scan on t_agg  (cost=0.00..163696.15 rows=10000115 width=19) (actual time=1.557..741.097 rows=10000000 loops=1)
 Planning Time: 0.114 ms
 Execution Time: 4575.441 ms
(6 行)
```

集計順序を変えると僅かにパフォーマンスが上がります

```sql
sample=# select count(distinct x), count(distinct y) from t_agg;
 count | count
-------+-------
     2 | 10000
(1 行)
```

実行計画に差異はありませんが、多様性の低いデータを後に記述したほうがハッシュ集計が効率的に実施されます。
