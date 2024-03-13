# テーブル結合順序のパフォーマンス

## お題

参考ページを見ても体感的には違うと感じていたため  
テーブル結合順序のパフォーマンスについて調査します

## 参考

https://www.postgresql.org/docs/current/explicit-joins.html

次のようなクエリはプランナーは、指定されたテーブルを任意の順序で自由に結合できます。テーブルが 3 つ以内の場合は、ある程度最適化の努力をするようです。

```sql
SELECT * FROM a, b, c WHERE a.id = b.id AND b.ref = c.id;
```

## 実験

[環境]

- Ubuntu 22.04
- PostgreSQL 14

psql Cli から DB 作成後にアクセス

```
root@masami-L ~# createdb -U postgres sample
root@masami-L /# psql -U postgres -d sample
```

データ準備

```Sql
sample=# create table t_min (
id serial,
val int default random()*100
);
CREATE TABLE
sample=# create table t_mid (
id serial,
val int default random()*100
);
CREATE TABLE
sample=# create table t_max (
id serial,
val int default random()*100
);
CREATE TABLE
sample=# insert into t_min select from generate_series(1, 100);
INSERT 0 100
sample=# insert into t_mid select from generate_series(1, 10000);
INSERT 0 10000
sample=# insert into t_max select from generate_series(1, 1000000);
INSERT 0 1000000
sample=# analyze;
ANALYZE
```

下記クエリのテーブル順序を変更しながらパフォーマンス測定しました

explain analyze select \* from `table_A` join `table_B` using (val) join `table_C` using (val);

| table_A | table_B | table_C | 実行時間(秒) |
| ------- | ------- | ------- | ------------ |
| min     | mid     | max     | 17           |
| min     | max     | mid     | 17           |
| mid     | min     | max     | 13           |
| mid     | max     | min     | 12           |
| max     | min     | mid     | 12           |
| max     | mid     | min     | 12           |

結合の最適化はテーブル 8 つまでに設定しています

```
sample=# show join_collapse_limit;
 join_collapse_limit
---------------------
 8
(1 行)
```

3 つのテーブルであれば結合順序を最適化するということでしたが、実際にはそうでもなく、納得感のある結果になりました。

２つの例の実行計画を見てみます

### ■ min <- mid <- max

```sql
explain analyze select * from t_min join t_mid using (val) join t_max using (val);
```

```
                                                         QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=26928.25..1180958.88 rows=101088378 width=16) (actual time=339.956..14065.074 rows=101313611 loops=1)
   Hash Cond: (t_min.val = t_max.val)
   ->  Hash Join  (cost=3.25..349.33 rows=10108 width=16) (actual time=138.852..148.659 rows=10139 loops=1)
         Hash Cond: (t_mid.val = t_min.val)
         ->  Seq Scan on t_mid  (cost=0.00..145.00 rows=10000 width=8) (actual time=0.008..3.627 rows=10000 loops=1)
         ->  Hash  (cost=2.00..2.00 rows=100 width=8) (actual time=138.829..138.831 rows=100 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 12kB
               ->  Seq Scan on t_min  (cost=0.00..2.00 rows=100 width=8) (actual time=138.781..138.796 rows=100 loops=1)
   ->  Hash  (cost=14425.00..14425.00 rows=1000000 width=8) (actual time=200.443..200.443 rows=1000000 loops=1)
         Buckets: 1048576  Batches: 1  Memory Usage: 47255kB
         ->  Seq Scan on t_max  (cost=0.00..14425.00 rows=1000000 width=8) (actual time=0.019..69.734 rows=1000000 loops=1)
 Planning Time: 0.199 ms
 JIT:
   Functions: 18
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.828 ms, Inlining 2.428 ms, Optimization 87.535 ms, Emission 48.861 ms, Total 139.652 ms
 Execution Time: 17435.287 ms
(17 rows)
```

![min_mid_max](https://github.com/pea-sys/postgresql-expriments/assets/49807271/f6e2a7ff-550a-46fe-89a0-008696004459)

### ■ max <- mid <- min

```Sql
explain analyze select * from t_max join t_mid using (val) join t_min using (val);
```

```
                                                         QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=273.25..1187869.45 rows=99565718 width=16) (actual time=148.016..8931.606 rows=101313611 loops=1)
   Hash Cond: (t_max.val = t_mid.val)
   ->  Hash Join  (cost=3.25..34429.08 rows=1000083 width=16) (actual time=146.118..445.259 rows=999256 loops=1)
         Hash Cond: (t_max.val = t_min.val)
         ->  Seq Scan on t_max  (cost=0.00..14425.00 rows=1000000 width=8) (actual time=0.010..91.621 rows=1000000 loops=1)
         ->  Hash  (cost=2.00..2.00 rows=100 width=8) (actual time=146.089..146.091 rows=100 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 12kB
               ->  Seq Scan on t_min  (cost=0.00..2.00 rows=100 width=8) (actual time=0.005..0.015 rows=100 loops=1)
   ->  Hash  (cost=145.00..145.00 rows=10000 width=8) (actual time=1.874..1.875 rows=10000 loops=1)
         Buckets: 16384  Batches: 1  Memory Usage: 519kB
         ->  Seq Scan on t_mid  (cost=0.00..145.00 rows=10000 width=8) (actual time=0.008..0.740 rows=10000 loops=1)
 Planning Time: 0.241 ms
 JIT:
   Functions: 17
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.857 ms, Inlining 2.458 ms, Optimization 92.695 ms, Emission 50.914 ms, Total 146.925 ms
 Execution Time: 12294.728 ms
(17 rows)

```

![max min mid](https://github.com/pea-sys/postgresql-expriments/assets/49807271/f1e6e4ae-0273-4ed5-a36b-7d52f2aac868)

テーブルの結合順序は２例で異なっており、最適化されていません。  
通常、最大行を持つテーブルを最初に内部結合したほうが、良いはずですが、きっと他にも色々と条件を見ているのだと思われます。

各テーブルがフラットに扱われるようなクエリだと最適化が効かないケースがあります。

次のサイトにあるように結合順序を強制するいくつかのトリックがあります。

https://www.cybertec-postgresql.com/en/forcing-a-join-order-in-postgresql/

### ■ サブクエリ内で `offset 0` を使用

`offset 0`を入れることでサブクエリのプルアップ(展開)がされないため、サブクエリがメインクエリと同等に扱われなくなります。

```sql
select * from t_mid join
(select * from t_min join t_max using (val) offset 0) as subq using (val);
```

```

                                                         QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=273.25..860909.01 rows=65869603 width=16) (actual time=152.737..9105.878 rows=101313611 loops=1)
   Hash Cond: (t_min.val = t_mid.val)
   ->  Hash Join  (cost=3.25..34429.08 rows=1000083 width=12) (actual time=150.255..462.506 rows=999256 loops=1)
         Hash Cond: (t_max.val = t_min.val)
         ->  Seq Scan on t_max  (cost=0.00..14425.00 rows=1000000 width=8) (actual time=0.010..101.415 rows=1000000 loops=1)
         ->  Hash  (cost=2.00..2.00 rows=100 width=8) (actual time=150.230..150.231 rows=100 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 12kB
               ->  Seq Scan on t_min  (cost=0.00..2.00 rows=100 width=8) (actual time=150.183..150.197 rows=100 loops=1)
   ->  Hash  (cost=145.00..145.00 rows=10000 width=8) (actual time=2.459..2.460 rows=10000 loops=1)
         Buckets: 16384  Batches: 1  Memory Usage: 519kB
         ->  Seq Scan on t_mid  (cost=0.00..145.00 rows=10000 width=8) (actual time=0.011..0.954 rows=10000 loops=1)
 Planning Time: 0.502 ms
 JIT:
   Functions: 19
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 1.838 ms, Inlining 3.109 ms, Optimization 100.011 ms, Emission 47.077 ms, Total 152.035 ms
 Execution Time: 12471.924 ms
(17 rows)
```

### ■CTE でマテビューの使用

実体化するので良し悪しあり

```sql
sample=# with subq as materialized (
sample(# select * from t_min join t_max using (val))
sample-# select * from t_mid join subq using (val);
```

```
                                                          QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=34699.08..712255.31 rows=50004150 width=16) (actual time=169.414..9575.257 rows=101313611 loops=1)
   Hash Cond: (subq.val = t_mid.val)
   CTE subq
     ->  Hash Join  (cost=3.25..34429.08 rows=1000083 width=12) (actual time=166.945..507.591 rows=999256 loops=1)
           Hash Cond: (t_max.val = t_min.val)
           ->  Seq Scan on t_max  (cost=0.00..14425.00 rows=1000000 width=8) (actual time=0.008..111.835 rows=1000000 loops=1)
           ->  Hash  (cost=2.00..2.00 rows=100 width=8) (actual time=166.922..166.923 rows=100 loops=1)
                 Buckets: 1024  Batches: 1  Memory Usage: 12kB
                 ->  Seq Scan on t_min  (cost=0.00..2.00 rows=100 width=8) (actual time=166.876..166.891 rows=100 loops=1)
   ->  CTE Scan on subq  (cost=0.00..20001.66 rows=1000083 width=12) (actual time=166.947..847.739 rows=999256 loops=1)
   ->  Hash  (cost=145.00..145.00 rows=10000 width=8) (actual time=2.444..2.444 rows=10000 loops=1)
         Buckets: 16384  Batches: 1  Memory Usage: 519kB
         ->  Seq Scan on t_mid  (cost=0.00..145.00 rows=10000 width=8) (actual time=0.011..0.946 rows=10000 loops=1)
 Planning Time: 0.147 ms
 JIT:
   Functions: 22
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.969 ms, Inlining 2.508 ms, Optimization 106.043 ms, Emission 58.340 ms, Total 167.861 ms
```

### ■join_collapse_limit を 1 にする

結合クエリのトランザクション内限定

```sql
sample=# set join_collapse_limit = 1;
SET
sample=# select * from t_min join t_max using (val) join t_mid using (val);
```

join_collapse_limit = 1; の時

```sql
----------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=273.25..1200952.42 rows=100904729 width=16) (actual time=148.149..9259.725 rows=101313611 loops=1)
   Hash Cond: (t_min.val = t_mid.val)
   ->  Hash Join  (cost=3.25..34410.75 rows=998250 width=16) (actual time=146.241..450.052 rows=999256 loops=1)
         Hash Cond: (t_max.val = t_min.val)
         ->  Seq Scan on t_max  (cost=0.00..14425.00 rows=1000000 width=8) (actual time=0.032..97.936 rows=1000000 loops=1)
         ->  Hash  (cost=2.00..2.00 rows=100 width=8) (actual time=146.193..146.195 rows=100 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 12kB
               ->  Seq Scan on t_min  (cost=0.00..2.00 rows=100 width=8) (actual time=146.146..146.160 rows=100 loops=1)
   ->  Hash  (cost=145.00..145.00 rows=10000 width=8) (actual time=1.883..1.883 rows=10000 loops=1)
         Buckets: 16384  Batches: 1  Memory Usage: 519kB
         ->  Seq Scan on t_mid  (cost=0.00..145.00 rows=10000 width=8) (actual time=0.009..0.736 rows=10000 loops=1)
 Planning Time: 0.154 ms
 JIT:
   Functions: 18
   Options: Inlining true, Optimization true, Expressions true, Deforming true
   Timing: Generation 0.790 ms, Inlining 2.964 ms, Optimization 93.700 ms, Emission 49.496 ms, Total 146.950 ms
 Execution Time: 12623.402 ms
(17 rows)
```

他には、pg_hint_plans 拡張を使う方法があります。  
また、`where` 句で絞込を行う場合は、結合前のテーブルに対して行うとパフォーマンスは改善します
