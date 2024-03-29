# UNION ALL のパフォーマンスについて

本内容の結論としては、UNION ALL を使用する場合、　　
型をしっかり合わせないと実行計画の最適化が効かないことがあるということです。

次の記事にあるパフォーマンス検証記事をトレースします

https://www.cybertec-postgresql.com/en/union-all-data-types-performance/

psql Cli から DB 作成後にアクセス

```
root@masami-L ~# createdb -U postgres sample
root@masami-L /# psql -U postgres -d sample
```

## UNION ALL ポリモーフィズムを実装する

```sql
sample=# create sequence seq;
CREATE SEQUENCE
sample=# create sequence seq;
ERROR:  relation "seq" already exists
sample=# create table bird (
id bigint primary key default nextval('seq'),
wingspan real not null,
beak_size double precision not null
);
CREATE TABLE

sample=# create table bat (
id bigint primary key default nextval('seq'),
wingspan numeric not null,
body_temperature numeric not null
);
CREATE TABLE

sample=# create table cat (
id bigint primary key default nextval('seq'),
body_temperature numeric not null,
tail_length numeric
);
CREATE TABLE

sample=# create view flying_animal as
sample-# select id, wingspan from bird
sample-# union all
sample-# select id, wingspan from bat;
CREATE VIEW

sample=# create view mammal as
select id, body_temperature from bat
union all
select id, body_temperature from cat;
CREATE VIEW
```

テーブルにランダムなデータを登録

```Sql
sample=# insert into bird (wingspan, beak_size)
sample-# select 20 + random() * 5 , 2 + random()
sample-# from generate_series(1, 1000000);
INSERT 0 1000000

sample=# insert into bat ( wingspan, body_temperature)
select 15 + random() * 5, 40 + random() * 2
from generate_series(1, 1000000);
INSERT 0 1000000

sample=# insert into cat ( body_temperature, tail_length)
select 36.5 + random(), 20 + random() * 3
from generate_series(1, 1000000);
INSERT 0 1000000
```

小さなルックアップテーブルを作成

```sql
sample=# create table lookup (
sample(# id bigint primary key
sample(# );
CREATE TABLE
sample=# insert into lookup
sample-# values (42), (500000), (1500000), (1700000), (2500000),(270000);
INSERT 0 6
sample=# analyze lookup;
ANALYZE
```

JOIN のパフォーマンス測定をします

```sql
sample=# select * from flying_animal join lookup using (id);
   id    | wingspan
---------+-----------
      42 | 21.431414
  270000 | 24.572584
  500000 | 24.519455
 1500000 |  16.62408
 1700000 | 18.741608
(5 rows)

Time: 772.166 ms
sample=# select * from mammal join lookup using (id);
   id    | body_temperature
---------+------------------
 1500000 | 40.2551073749159
 1700000 | 40.5690611488794
 2500000 | 36.8683292859752
(3 rows)

Time: 6.065 ms
```

flyng_animal テーブルの join が mammal より 100 倍以上遅いです

### 差異の調査

実行計画を確認します

flying_animal の JOIN

```sql
sample=# explain (analyze, costs off)
select * from flying_animal join lookup using (id);
                                         QUERY PLAN
---------------------------------------------------------------------------------------------
 Hash Join (actual time=0.229..1070.283 rows=5 loops=1)
   Hash Cond: (bird.id = lookup.id)
   ->  Append (actual time=0.123..897.762 rows=2000000 loops=1)
         ->  Seq Scan on bird (actual time=0.121..153.820 rows=1000000 loops=1)
         ->  Subquery Scan on "*SELECT* 2" (actual time=0.036..600.560 rows=1000000 loops=1)
               ->  Seq Scan on bat (actual time=0.029..136.890 rows=1000000 loops=1)
   ->  Hash (actual time=0.038..0.039 rows=6 loops=1)
         Buckets: 1024  Batches: 1  Memory Usage: 9kB
         ->  Seq Scan on lookup (actual time=0.013..0.017 rows=6 loops=1)
 Planning Time: 0.543 ms
 Execution Time: 1070.346 ms
(11 rows)

Time: 1072.218 ms (00:01.072)
```

mammal の JOIN

```sql
sample=# explain (analyze, costs off)
sample-# select * from mammal join lookup using (id);
                                       QUERY PLAN
----------------------------------------------------------------------------------------
 Nested Loop (actual time=0.104..0.164 rows=3 loops=1)
   ->  Seq Scan on lookup (actual time=0.017..0.020 rows=6 loops=1)
   ->  Append (actual time=0.019..0.022 rows=0 loops=6)
         ->  Index Scan using bat_pkey on bat (actual time=0.011..0.011 rows=0 loops=6)
               Index Cond: (id = lookup.id)
         ->  Index Scan using cat_pkey on cat (actual time=0.008..0.008 rows=0 loops=6)
               Index Cond: (id = lookup.id)
 Planning Time: 0.542 ms
 Execution Time: 0.224 ms
(9 rows)

Time: 1.549 ms
```

flying_animal の JOIN はテーブルスキャンで、mammal の JOIN はインデックススキャンが使われています

この差異の要因は、各テーブルの wingspan の型定義の違いによるものです

| テーブル | wingspan の型 |
| -------- | ------------- |
| bird     | real          |
| bat      | numeric       |
| cat      | numeric       |

bird テーブルの型を合わせる

```sql
sample=# drop view flying_animal;
DROP VIEW
Time: 5.604 ms
sample=# alter table bird alter column wingspan type numeric;
ALTER TABLE
Time: 2298.310 ms (00:02.298)
sample=# create view flying_animal as
select id, wingspan from bird
union all
select id, wingspan from bat;
CREATE VIEW
Time: 6.268 ms
sample=# insert into bird (wingspan, beak_size)
select 20 + random() * 5 , 2 + random()
from generate_series(1, 1000000);
INSERT 0 1000000
Time: 4979.005 ms (00:04.979)
sample=# analyze;
ANALYZE
Time: 1428.478 ms (00:01.428)
```

再度、パフォーマンスを測定します

```sql
sample=# explain (analyze, costs off)
select * from flying_animal join lookup using (id);
                                        QUERY PLAN
------------------------------------------------------------------------------------------
 Nested Loop (actual time=0.028..0.098 rows=5 loops=1)
   ->  Seq Scan on lookup (actual time=0.008..0.010 rows=6 loops=1)
   ->  Append (actual time=0.010..0.013 rows=1 loops=6)
         ->  Index Scan using bird_pkey on bird (actual time=0.006..0.007 rows=0 loops=6)
               Index Cond: (id = lookup.id)
         ->  Index Scan using bat_pkey on bat (actual time=0.005..0.005 rows=0 loops=6)
               Index Cond: (id = lookup.id)
 Planning Time: 0.550 ms
 Execution Time: 0.137 ms
(9 rows)
```

インデックススキャンが使用され、速度も mammal と同等になりました  
テーブルの型変更が難しい場合は、キャストを使用します

一旦テーブルの型を元に戻します

```sql
sample=# drop view flying_animal;
DROP VIEW
sample=# drop table bird;
DROP TABLE
sample=# create table bird (
id bigint primary key default nextval('seq'),
wingspan real not null,
beak_size double precision not null
);
CREATE TABLE
sample=# create view flying_animal as
sample-# select id, wingspan from bird
sample-# union all
sample-# select id, wingspan from bat;
CREATE VIEW
sample=# insert into bird (wingspan, beak_size)
sample-# select 20 + random() * 5 , 2 + random()
sample-# from generate_series(1, 1000000);
INSERT 0 1000000
```

表現力の低い方の型を高い方に合わせてキャストします

```sql
sample=# create or replace view flying_animal as
sample-# select id, wingspan from bird
sample-# union all
sample-# select id, wingspan::real from bat;
CREATE VIEW
```

インデックススキャンが使用されるようになりました

```sql
sample=# explain (analyze, costs off)
select * from flying_animal join lookup using (id);
                                        QUERY PLAN
------------------------------------------------------------------------------------------
 Nested Loop (actual time=3.615..4.986 rows=2 loops=1)
   ->  Seq Scan on lookup (actual time=0.011..0.017 rows=6 loops=1)
   ->  Append (actual time=0.824..0.825 rows=0 loops=6)
         ->  Index Scan using bird_pkey on bird (actual time=0.007..0.007 rows=0 loops=6)
               Index Cond: (id = lookup.id)
         ->  Index Scan using bat_pkey on bat (actual time=0.814..0.814 rows=0 loops=6)
               Index Cond: (id = lookup.id)
 Planning Time: 0.433 ms
 Execution Time: 5.069 ms
(9 rows)
```
