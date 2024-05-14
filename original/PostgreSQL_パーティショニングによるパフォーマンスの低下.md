# パーティショニングによるパフォーマンスの低下

次の記事にあるパフォーマンス検証記事をトレースします  
パーティションの基準列以外で検索する場合は、パーティションを使った場合の方が遅いよという内容です。  
ファイル分割されている分、オーバーヘッドはあるのでそうだろうなという感じです。

https://www.cybertec-postgresql.com/en/killing-performance-with-postgresql-partitioning/

■ 検索性能測定結果  
※キャッシュが効かないように初回クエリの測定値を採用

| テーブル           | パーティション基準列 | パーティション基準列以外 |
| ------------------ | -------------------- | ------------------------ |
| パーティションなし | 453.3 ms             | 9.5ms                    |
| パーティションあり | 79.437 ms            | 14.5ms                   |

psql Cli から DB 作成後にアクセス

```
root@masami-L ~# createdb -U postgres sample
root@masami-L /# psql -U postgres -d sample
```

### ■ パーティションを使用しない場合のパフォーマンス確認

テーブルの準備

```sql
sample=# create table t_simple (
sample(# id serial,
sample(# val int default random()*100000
sample(# );
CREATE TABLE
sample=# insert into t_simple
sample-# select from generate_series(1, 10000000);
INSERT 0 10000000
sample=# create index on t_simple (val);
CREATE INDEX
sample=# vacuum analyze;
VACUUM
```

パーティション基準列のパフォーマンス測定

```sql
sample=# explain (analyze,buffers, costs)
select *
from t_simple
where id = 1922919;
                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..97331.31 rows=1 width=8) (actual time=448.519..453.134 rows=1 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   Buffers: shared read=44248
   ->  Parallel Seq Scan on t_simple  (cost=0.00..96331.21 rows=1 width=8) (actual time=313.486..427.788 rows=0 loops=3)
         Filter: (id = 1922919)
         Rows Removed by Filter: 3333333
         Buffers: shared read=44248
 Planning:
   Buffers: shared hit=16 read=1
 Planning Time: 0.185 ms
 Execution Time: 453.152 ms
(12 rows)
```

パーティション基準列以外のパフォーマンス測定

```sql
sample=# explain (analyze,buffers, costs)
select *
from t_simple
where val = 454650;
                                                        QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on t_simple  (cost=5.21..392.20 rows=100 width=8) (actual time=0.832..0.832 rows=0 loops=1)
   Recheck Cond: (val = 454650)
   Buffers: shared read=3
   ->  Bitmap Index Scan on t_simple_val_idx  (cost=0.00..5.18 rows=100 width=0) (actual time=0.828..0.828 rows=0 loops=1)
         Index Cond: (val = 454650)
         Buffers: shared read=3
 Planning:
   Buffers: shared hit=43 read=21
 Planning Time: 8.035 ms
 Execution Time: 1.511 ms
(10 rows)
```

### ■ パーティションを使用する場合のパフォーマンス確認

テーブルの準備

```sql
sample=# create table t_part (
sample(# id serial,
sample(# val int default random()*100000)
sample-# partition by hash (id);
CREATE TABLE

sample=# create table t_part_1
partition of t_part
for values with (modulus 8, remainder 0);
CREATE TABLE
sample=# create table t_part_2
partition of t_part
for values with (modulus 8, remainder 1);
CREATE TABLE
sample=# create table t_part_3
partition of t_part
for values with (modulus 8, remainder 2);
CREATE TABLE
sample=# create table t_part_4
partition of t_part
for values with (modulus 8, remainder 3);
CREATE TABLE
sample=# create table t_part_5
partition of t_part
for values with (modulus 8, remainder 4);
CREATE TABLE
sample=# create table t_part_6
partition of t_part
for values with (modulus 8, remainder 5);
CREATE TABLE
sample=# create table t_part_7
partition of t_part
for values with (modulus 8, remainder 6);
CREATE TABLE
sample=# create table t_part_8
partition of t_part
for values with (modulus 8, remainder 7);
CREATE TABLE
sample=# insert into t_part
sample-# select from generate_series(1, 10000000);
INSERT 0 10000000
sample=# vacuum analyze;
VACUUM
```

パーティション基準列のパフォーマンス測定

```sql
sample=# SELECT * FROM t_part TABLESAMPLE SYSTEM(0.01);
sample=# explain (analyze,buffers, costs)
select *
from t_part
where id = 1922919;
                                                          QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..13036.50 rows=1 width=8) (actual time=39.271..90.171 rows=1 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   Buffers: shared hit=1948 read=3581
   ->  Parallel Seq Scan on t_part_3 t_part  (cost=0.00..12036.40 rows=1 width=8) (actual time=44.116..59.104 rows=0 loops=3)
         Filter: (id = 1922919)
         Rows Removed by Filter: 416473
         Buffers: shared hit=1948 read=3581
 Planning Time: 0.290 ms
 Execution Time: 90.211 ms
(10 rows)
```

パーティション基準列以外のパフォーマンス測定

```sql
sample=# explain (analyze,buffers, costs)
select *
from t_part
where val = 454650;
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
Append  (cost=4.54..450.33 rows=107 width=8) (actual time=6.474..6.478 rows=0 loops=1)
   Buffers: shared read=24
   ->  Bitmap Heap Scan on t_part_1  (cost=4.54..58.60 rows=14 width=8) (actual time=0.815..0.815 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_1_val_idx  (cost=0.00..4.53 rows=14 width=0) (actual time=0.809..0.809 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
   ->  Bitmap Heap Scan on t_part_2  (cost=4.53..54.80 rows=13 width=8) (actual time=0.853..0.853 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_2_val_idx  (cost=0.00..4.53 rows=13 width=0) (actual time=0.851..0.851 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
   ->  Bitmap Heap Scan on t_part_3  (cost=4.54..58.60 rows=14 width=8) (actual time=0.826..0.826 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_3_val_idx  (cost=0.00..4.53 rows=14 width=0) (actual time=0.812..0.812 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
   ->  Bitmap Heap Scan on t_part_4  (cost=4.54..58.60 rows=14 width=8) (actual time=0.772..0.772 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_4_val_idx  (cost=0.00..4.53 rows=14 width=0) (actual time=0.769..0.769 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
   ->  Bitmap Heap Scan on t_part_5  (cost=4.53..54.80 rows=13 width=8) (actual time=0.775..0.775 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_5_val_idx  (cost=0.00..4.53 rows=13 width=0) (actual time=0.774..0.774 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
   ->  Bitmap Heap Scan on t_part_6  (cost=4.53..54.80 rows=13 width=8) (actual time=0.786..0.787 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_6_val_idx  (cost=0.00..4.53 rows=13 width=0) (actual time=0.783..0.783 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
   ->  Bitmap Heap Scan on t_part_7  (cost=4.53..54.80 rows=13 width=8) (actual time=0.791..0.791 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_7_val_idx  (cost=0.00..4.53 rows=13 width=0) (actual time=0.790..0.790 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
   ->  Bitmap Heap Scan on t_part_8  (cost=4.53..54.80 rows=13 width=8) (actual time=0.851..0.852 rows=0 loops=1)
         Recheck Cond: (val = 454650)
         Buffers: shared read=3
         ->  Bitmap Index Scan on t_part_8_val_idx  (cost=0.00..4.53 rows=13 width=0) (actual time=0.850..0.850 rows=0 loops=1)
               Index Cond: (val = 454650)
               Buffers: shared read=3
 Planning:
   Buffers: shared hit=272 read=23
 Planning Time: 7.996 ms
 Execution Time: 6.663 ms
(54 rows)
```
