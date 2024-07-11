# 外部キーのインデックスの作成とパフォーマンス

外部キーが適切に機能するためにはインデックスが必要だよという記事のトレースです

https://www.cybertec-postgresql.com/en/index-your-foreign-key/

PostgreSQL では外部キーのソースにインデックスを必要としませんが、張った方が良い

データベース作成

```
root@masami-L ~# createdb -U postgres sample
root@masami-L /# psql -U postgres -d sample
```

データ作成

```Sql
sample=# set max_parallel_workers_per_gather = 0;
SET
sample=# set maintenance_work_mem  = '512MB';
SET
sample=# set max_parallel_workers_per_gather = 0;
SET
sample=# set maintenance_work_mem  = '512MB';
SET
sample=# create table target (
sample(# t_id integer not null,
sample(# t_name text not null
sample(# );
CREATE TABLE
sample=# insert into target (t_id, t_name)
select i, 'target ' || i
from generate_series(1, 500001) as i;
INSERT 0 500001
sample=# alter table target
sample-# add primary key (t_id);
ALTER TABLE
sample=# create index on target(t_name);
CREATE INDEX
sample=# create table source (
sample(# s_id integer not null,
sample(# t_id integer not null,
sample(# s_name text not null
sample(# );
CREATE TABLE
sample=# insert into source (s_id, t_id, s_name)
sample-# select i, (i - 1) % 500000 + 1, 'source ' || i
sample-# from generate_series(1, 1000000) as i;
INSERT 0 1000000
sample=# alter table source
sample-# add primary key (s_id);
ALTER TABLE
sample=# alter table source
add foreign key (t_id) references target;
ALTER TABLE
sample=# vacuum (analyze) source;
VACUUM
```

### インデックスを使用しない場合のクエリ時間

```sql
sample=# explain (analyze)
sample-# select source.s_name
sample-# from source
sample-# join target using (t_id)
sample-# where target.t_name = 'target 42';
                                                              QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=8.45..19003.47 rows=2 width=13) (actual time=0.112..169.440 rows=2 loops=1)
   Hash Cond: (source.t_id = target.t_id)
   ->  Seq Scan on source  (cost=0.00..16370.00 rows=1000000 width=17) (actual time=0.005..72.070 rows=1000000 loops=1)
   ->  Hash  (cost=8.44..8.44 rows=1 width=4) (actual time=0.084..0.085 rows=1 loops=1)
         Buckets: 1024  Batches: 1  Memory Usage: 9kB
         ->  Index Scan using target_t_name_idx on target  (cost=0.42..8.44 rows=1 width=4) (actual time=0.079..0.080 rows=1 loops=1)
               Index Cond: (t_name = 'target 42'::text)
 Planning Time: 0.245 ms
 Execution Time: 169.467 ms
(9 rows)


sample=# explain (analyze)
sample-# delete from target
sample-# where target.t_name = 'target 500001';
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Delete on target  (cost=0.42..8.44 rows=0 width=0) (actual time=0.127..0.128 rows=0 loops=1)
   ->  Index Scan using target_t_name_idx on target  (cost=0.42..8.44 rows=1 width=6) (actual time=0.088..0.090 rows=1 loops=1)
         Index Cond: (t_name = 'target 500001'::text)
 Planning Time: 0.258 ms
 Trigger for constraint source_t_id_fkey: time=73.377 calls=1
 Execution Time: 73.594 ms
(6 rows)
```

### インデックスを使用した場合のクエリ時間

インデックスを貼ります

```sql
sample=# create index source_t_id_idx on source (t_id);
CREATE INDEX
```

先述のクエリが何百倍も速くなります。

```sql
sample=# explain (analyze)
sample-# select source.s_name
sample-# from source
sample-# join target using (t_id)
sample-# where target.t_name = 'target 42';
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=0.85..19.90 rows=2 width=13) (actual time=0.059..0.068 rows=2 loops=1)
   ->  Index Scan using target_t_name_idx on target  (cost=0.42..8.44 rows=1 width=4) (actual time=0.040..0.041 rows=1 loops=1)
         Index Cond: (t_name = 'target 42'::text)
   ->  Index Scan using source_t_id_idx on source  (cost=0.42..11.44 rows=2 width=17) (actual time=0.011..0.016 rows=2 loops=1)
         Index Cond: (t_id = target.t_id)
 Planning Time: 1.011 ms
 Execution Time: 0.116 ms
(7 rows)

sample=# explain (analyze)
sample-# delete from target
sample-# where target.t_name = 'target 500001';
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Delete on target  (cost=0.42..8.44 rows=0 width=0) (actual time=0.039..0.040 rows=0 loops=1)
   ->  Index Scan using target_t_name_idx on target  (cost=0.42..8.44 rows=1 width=6) (actual time=0.038..0.038 rows=0 loops=1)
         Index Cond: (t_name = 'target 500001'::text)
 Planning Time: 0.076 ms
 Execution Time: 0.064 ms
(5 rows)
```

### 欠落しているインデックスを確認する

次のクエリはインデックスを持たない外部キーを抽出します

```sql
sample=# drop index source_t_id_idx;
DROP INDEX
sample=# select c.conrelid::regclass as "table",
string_agg(a.attname, ',' order by x.n) as columns,
pg_size_pretty(pg_relation_size(c.conrelid)
) as size,
c.conname as constraint,
c.confrelid::regclass as referenced_table
from pg_constraint c
cross join lateral
unnest(c.conkey) with ordinality as x(attnum, n)
join pg_attribute a
on a.attnum = x.attnum
and a.attrelid = c.conrelid
where not exists
(select 1 from pg_index i
where i.indrelid = c.conrelid
and i.indpred is null
and (i.indkey::smallint[])[0:cardinality(c.conkey)-1]
operator(@>) c.conkey)
and c.contype = 'f'
group by c.conrelid, c.conname, c.confrelid
order by pg_relation_size(c.conrelid) desc;
 table  | columns | size  |    constraint    | referenced_table
--------+---------+-------+------------------+------------------
 source | t_id    | 50 MB | source_t_id_fkey | target
(1 row)
```
