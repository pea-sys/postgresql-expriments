# パフォーマンス向上のため `OR` の使用を避ける

次の記事のトレースをします

https://www.cybertec-postgresql.com/en/avoid-or-for-better-performance/

https://www.cybertec-postgresql.com/en/rewrite-or-to-union-in-postgresql-queries/

- データベースの作成

```
root@masami-L /# createdb -U postgres sample
root@masami-L /# psql -U postgres -d sample
psql (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
Type "help" for help.
```

- データの準備

```sql
sample=# create table a(id integer not null, a_val text not null);
CREATE TABLE
sample=# insert into a select i, md5(i::text) from generate_series(1, 100000) i;
INSERT 0 100000
sample=# create table b(id integer not null, b_val text not null);
CREATE TABLE
sample=# insert into b select i, md5(i::text) from generate_series(1, 100000) i;
INSERT 0 100000
sample=# alter table a add primary key (id);
ALTER TABLE
sample=# alter table b add primary key (id);
ALTER TABLE
sample=# alter table b add foreign key (id) references a;
ALTER TABLE
sample=# vacuum (analyze) a;
VACUUM
sample=# vacuum (analyze) b;
VACUUM
sample=# show lc_collate;
 lc_collate
-------------
 ja_JP.UTF-8
(1 row)
sample=# create index a_val_idx on a(a_val text_pattern_ops);
CREATE INDEX
sample=# create index b_val_idx on a(a_val text_pattern_ops);
CREATE INDEX
```

※text_pattern_ops は like 演算子を使用するケースに適しています

### 良い `OR`

クエリ結果を`OR`しないケース

### 悪い `OR`

次のクエリはいい例です。

```sql
sample=# explain (costs off)
sample-# select id from a
sample-# where id = 42
sample-# or a_val = 'value 42';
                        QUERY PLAN
-----------------------------------------------------------
 Bitmap Heap Scan on a
   Recheck Cond: ((id = 42) OR (a_val = 'value 42'::text))
   ->  BitmapOr
         ->  Bitmap Index Scan on a_pkey
               Index Cond: (id = 42)
         ->  Bitmap Index Scan on b_val_idx
               Index Cond: (a_val = 'value 42'::text)
(7 rows)
```

両インデックスのビットマップを作成し、インデックススキャンされています。  
ビットマップ構築コストの分、インデックススキャンよりコストがかかります。  
ただし、特に改善が見込める代替クエリもありません。

### `OR` より `IN` の方が良いケース

```sql
sample=# explain (costs off)
sample-# select id from a
sample-# where id = 42
sample-#  or id = 4711;
                 QUERY PLAN
--------------------------------------------
 Bitmap Heap Scan on a
   Recheck Cond: ((id = 42) OR (id = 4711))
   ->  BitmapOr
         ->  Bitmap Index Scan on a_pkey
               Index Cond: (id = 42)
         ->  Bitmap Index Scan on a_pkey
               Index Cond: (id = 4711)
(7 rows)
```

インデックスのビットマップを作成し、インデックススキャンされています。  
`in`によりビットマップ作成コストを減らせます。  
※筆者環境では、実際測定してみると `or`の方がパフォーマンスはよかったです。

```sql

sample=# explain (costs off)
sample-# select id from a
sample-# where id in  ( 42, 4711);
                    QUERY PLAN
---------------------------------------------------
 Index Only Scan using a_pkey on a
   Index Cond: (id = ANY ('{42,4711}'::integer[]))
(2 rows)
```

```sql
sample=# explain (costs off)
sample-# select id from a
sample-# where a_val like 'something%'
sample-# or a_val like 'other%';
                                          QUERY PLAN
----------------------------------------------------------------------------------------------
 Bitmap Heap Scan on a
   Recheck Cond: ((a_val ~~ 'something%'::text) OR (a_val ~~ 'other%'::text))
   Filter: ((a_val ~~ 'something%'::text) OR (a_val ~~ 'other%'::text))
   ->  BitmapOr
         ->  Bitmap Index Scan on b_val_idx
               Index Cond: ((a_val ~>=~ 'something'::text) AND (a_val ~<~ 'somethinh'::text))
         ->  Bitmap Index Scan on b_val_idx
               Index Cond: ((a_val ~>=~ 'other'::text) AND (a_val ~<~ 'othes'::text))
(8 rows)
```

```sql
sample=# explain (costs off)
sample-# select id from a
sample-# where a_val like any (array['something%','other%']);
                        QUERY PLAN
----------------------------------------------------------
 Seq Scan on a
   Filter: (a_val ~~ ANY ('{something%,other%}'::text[]))
(2 rows)
```

インデックススキャンは使われなくなりました。
pg_trgm を導入することで、このクエリで index scan を使用できるようにします

### pg_trgm の助け

pg_trgm モジュールは、テキスト列全体に非常に高速な類似度検索を行うためのインデックスを作成することができます。

導入

```sql
sample=# create extension pg_trgm;
CREATE EXTENSION
sample=# create index a_val_trgm_idx on a using gin (a_val gin_trgm_ops);
CREATE INDEX
```

```sql
sample=# explain (costs off)
select id from a
where a_val like any (array['something%','other%']);
                             QUERY PLAN
--------------------------------------------------------------------
 Bitmap Heap Scan on a
   Recheck Cond: (a_val ~~ ANY ('{something%,other%}'::text[]))
   ->  Bitmap Index Scan on a_val_trgm_idx
         Index Cond: (a_val ~~ ANY ('{something%,other%}'::text[]))
(4 rows)
```

### 良くない `OR` のケース

`Where`における複数テーブルの`OR`条件は良くないケースです。

```sql
sample=# explain (costs off)
select id, a.a_val, b.b_val
from a join b using (id)
where a.id = 42
or b.id = 42;
                 QUERY PLAN
---------------------------------------------
 Hash Join
   Hash Cond: (a.id = b.id)
   Join Filter: ((a.id = 42) OR (b.id = 42))
   ->  Seq Scan on a
   ->  Hash
         ->  Seq Scan on b
(6 rows)
```

### 良くない `OR` を避けるケース

```Sql
sample=# explain (costs off)
select id, a.a_val, b.b_val
from a join b using (id)
where a.id = 42
union
select id, a.a_val, b.b_val
from a join b using (id)
where b.id = 42;
                        QUERY PLAN
----------------------------------------------------------
 Unique
   ->  Sort
         Sort Key: a.id, a.a_val, b.b_val
         ->  Append
               ->  Nested Loop
                     ->  Index Scan using a_pkey on a
                           Index Cond: (id = 42)
                     ->  Index Scan using b_pkey on b
                           Index Cond: (id = 42)
               ->  Nested Loop
                     ->  Index Scan using a_pkey on a a_1
                           Index Cond: (id = 42)
                     ->  Index Scan using b_pkey on b b_1
                           Index Cond: (id = 42)
(14 rows)
```

`UNION`を使用すると、実行ははるかに早いです(約 100 倍)  
`UNION`するテーブルが完全に個別のセットを返す場合は`UNION ALL`にすることで更に効率的なクエリになります

### `OR`の`UNION`置換可能性

ただし、`OR`の`UNION`への置き換えは必ず等価になるとは限りません。

具体例を見ていきます。

データの準備

```sql
sample=# create table a (
id integer generated always as identity primary key,
x integer,
p integer
);
CREATE TABLE
sample=# create table b (
id integer generated always as identity primary key,
x integer,
q integer
);
CREATE TABLE
sample=# insert into a (x, p) values
sample-# (1, 1),
sample-# (1, 1),
sample-# (2, 1);
INSERT 0 3
sample=# insert into b (x, q) values
(1, 3),
(2, 3);
INSERT 0 2
```

クエリ結果の差異を確認

```Sql
sample=# select x, a.p, b.q
sample-# from a join b using (x)
sample-# where a.p = 1 or  b.q = 3;
 x | p | q
---+---+---
 1 | 1 | 3
 1 | 1 | 3
 2 | 1 | 3
(3 rows)

sample=# select x, a.p, b.q
sample-# from a join b using (x)
sample-# where a.p = 1
sample-# union
sample-# select x, a.p , b.q
sample-# from a join b using (x)
sample-# where b.q = 3;
 x | p | q
---+---+---
 2 | 1 | 3
 1 | 1 | 3
(2 rows)
```

`union`による重複キー排除により、結果が変わってます。  
では、`union all`を使えば良いかというとそうでもありません。

```sql
sample=# select x, a.p, b.q
from a join b using (x)
where a.p = 1
union all
select x, a.p , b.q
from a join b using (x)
where b.q = 3;
 x | p | q
---+---+---
 1 | 1 | 3
 1 | 1 | 3
 2 | 1 | 3
 1 | 1 | 3
 1 | 1 | 3
 2 | 1 | 3
(6 rows)
```

`OR`を`UNION`に変換する安全なケースは NULL 以外の一意のキーがリストに含まれている場合に限られますが、一般的にはそのようなケースに該当するので
多くの場合は置換可能です。
