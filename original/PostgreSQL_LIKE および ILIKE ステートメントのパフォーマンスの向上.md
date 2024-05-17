# LIKE および ILIKE ステートメントのパフォーマンスの向上

勉強のため次の記事のトレースをします。

https://www.cybertec-postgresql.com/en/postgresql-more-performance-for-like-and-ilike-statements/

データベース準備

```
root@masami-L ~# sudo -i -u postgres
postgres@masami-L:~$ createdb -U postgres sample
postgres@masami-L:~$ psql -U postgres -d sample
```

データ準備

```sql
sample=# create table t_hash as
sample-# select id, md5(id::text)
sample-# from generate_series(1, 50000000 ) as id;
SELECT 50000000
sample=# vacuum analyze;
VACUUM
```

テーブルのサンプル

```Sql
sample=# select * from t_hash limit 10;
 id |               md5
----+----------------------------------
  1 | c4ca4238a0b923820dcc509a6f75849b
  2 | c81e728d9d4c2f636f067f89cc14862c
  3 | eccbc87e4b5ce2fe28308fd9f2a7baf3
  4 | a87ff679a2f3e71d9181a67b7542122c
  5 | e4da3b7fbbce2345d7772b0674a318d5
  6 | 1679091c5a880faf6fb5e6087eb1b2dc
  7 | 8f14e45fceea167a5a36dedd4bea2543
  8 | c9f0f895fb98ab9159f51fd0297e236d
  9 | 45c48cce2e2d7fbdea1afc51c7c6ad26
 10 | d3d9446802a44259755d38e6d163e820
(10 rows)
```

単純な like の例

```Sql
sample=# \timing
Timing is on.
sample=# select * from t_hash where md5 like '%e2345679%';
    id    |               md5
----------+----------------------------------
 37211731 | dadb4b54e2345679a8861ab52e4128ea
(1 row)

Time: 9252.238 ms (00:09.252)
```

9 秒掛かっており、非常に遅いです  
実行計画を見てみます

```Sql
sample=# explain select * from t_hash where md5 like '%e2345679%';
                                  QUERY PLAN
-------------------------------------------------------------------------------
 Gather  (cost=1000.00..678583.88 rows=5000 width=37)
   Workers Planned: 2
   ->  Parallel Seq Scan on t_hash  (cost=0.00..677083.88 rows=2083 width=37)
         Filter: (md5 ~~ '%e2345679%'::text)
 JIT:
   Functions: 2
   Options: Inlining true, Optimization true, Expressions true, Deforming true
(7 rows)

Time: 3.424 ms
```

並列シーケンシャルスキャンが使われています

```
sample=# \dt+
                                    List of relations
 Schema |  Name  | Type  |  Owner   | Persistence | Access method |  Size   | Description
--------+--------+-------+----------+-------------+---------------+---------+-------------
 public | t_hash | table | postgres | permanent   | heap          | 3256 MB |
```

ただし、テーブルサイズが大きいため非常に時間が掛かります  
1 つの行を取得するために 3.2GB をスキャンすることになります

### pg_trgm インデックスの作成

pg_trgm 拡張機能は、あいまい検索を支援する「trigrams」をサポートしています

```Sql
sample=# create extension pg_trgm;
CREATE EXTENSION
Time: 46.938 ms
```

トリグラムは次のように表現されます

```sql
sample=# select show_trgm('dadb454e2345679a8861ab52e4128ea');
-----------------------------------------------------------------------------------------------------------------------------------------
 {"  d"," da",128,1ab,234,28e,2e4,345,412,454,456,4e2,52e,54e,567,61a,679,79a,861,886,8ea,9a8,a88,ab5,adb,b45,b52,dad,db4,e23,e41,"ea "}
(1 row)
```

トリグラムはスライドする 3 文字のウィンドウのようなものです

### Gist を使用した trigram インデックスのデプロイ

あいまい検索を高速化するために多くの人が行っているのは gist インデックスを使用することです

```sql
sample=# create index idx_gist on t_hash using gist (md5 gist_trgm_ops);
CREATE INDEX
Time: 2254395.117 ms (37:34.395)
```

インデックスの構築にかなりの時間がかかるということです。ここで重要なのは、maintenance_work_mem の設定を高くしてもプロセスは高速化されないということです。 4 GB の maintenance_work_mem を使用した場合でも、プロセスには 40 分かかります。

また、注目すべき点は、インデックスが 9GB と非常に大きいことです。

```sql
sample=# \di+
                                          List of relations
 Schema |   Name   | Type  |  Owner   | Table  | Persistence | Access method |  Size   | Description
--------+----------+-------+----------+--------+-------------+---------------+---------+-------------
 public | idx_gist | index | postgres | t_hash | permanent   | gist          | 8781 MB |
(1 row)
```

更に悪いことにクエリは早くなりません

```Sql
sample=# select * from t_hash where md5 like '%e2345679%';
    id    |               md5
----------+----------------------------------
 37211731 | dadb4b54e2345679a8861ab52e4128ea
(1 row)

Time: 93427.202 ms (01:33.427)
```

実行計画は次のようになります

```sql
sample=# explain select * from t_hash where md5 like '%e2345679%';
                                 QUERY PLAN
----------------------------------------------------------------------------
 Bitmap Heap Scan on t_hash  (cost=491.30..18808.90 rows=5000 width=37)
   Recheck Cond: (md5 ~~ '%e2345679%'::text)
   ->  Bitmap Index Scan on idx_gist  (cost=0.00..490.05 rows=5000 width=0)
         Index Cond: (md5 ~~ '%e2345679%'::text)
(4 rows)

Time: 0.910 ms
```

ビットマップインデックススキャンを使っているので、代わりにインデックススキャンを使用するようにします  
しかし、相変わらず遅いです

```sql
sample=# explain  analyze select * from t_hash where md5 like '%e2345679%';
                                                           QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------
 Index Scan using idx_gist on t_hash  (cost=0.55..20424.04 rows=5000 width=37) (actual time=17832.779..99027.978 rows=1 loops=1)
   Index Cond: (md5 ~~ '%e2345679%'::text)
   Rows Removed by Index Recheck: 1
 Planning Time: 0.250 ms
 Execution Time: 99028.020 ms
(5 rows)

Time: 99028.658 ms (01:39.029)
```

Gist インデックスを使用するのは適切ではない可能性があります。作成には時間がかかり、サイズが大きく、シーケンシャル スキャンよりもはるかに時間がかかります。

### パターンマッチングに GIN インデックスを使用する

pg_trgm 拡張機能の GIN インデックスを使用してみます

```Sql
sample=# discard all;
DISCARD ALL
Time: 0.432 ms
sample=# drop index idx_gist;
DROP INDEX
Time: 803.505 ms
```

先ほどより２０分以上早くインデックスが作成できました

```sql
sample=# create index idx_gin on t_hash using gin (md5 gin_trgm_ops);
CREATE INDEX
Time: 772030.260 ms (12:52.030)
```

1 分 30 秒掛かっていたクエリが 0.1 秒で終わりました

```Sql
sample=# explain analyze select * from t_hash where md5 like '%e2345679%';
                                                        QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on t_hash  (cost=1966.75..20284.36 rows=5000 width=37) (actual time=112.491..112.493 rows=1 loops=1)
   Recheck Cond: (md5 ~~ '%e2345679%'::text)
   Rows Removed by Index Recheck: 1
   Heap Blocks: exact=2
   ->  Bitmap Index Scan on idx_gin  (cost=0.00..1965.50 rows=5000 width=0) (actual time=112.166..112.166 rows=2 loops=1)
         Index Cond: (md5 ~~ '%e2345679%'::text)
 Planning Time: 3.525 ms
 Execution Time: 112.515 ms
(8 rows)

Time: 116.536 ms
```

```sql
sample=# select * from t_hash where md5 like '%e2345679%';
    id    |               md5
----------+----------------------------------
 37211731 | dadb4b54e2345679a8861ab52e4128ea
(1 row)

Time: 91.445 ms
```

ただし、GIN は「=」演算子を高速化しません。

```sql
sample=# select * from t_hash where md5 = 'dadb4b54e2345679a8861ab52e4128ea';
    id    |               md5
----------+----------------------------------
 37211731 | dadb4b54e2345679a8861ab52e4128ea
(1 row)

Time: 765.149 ms
```

「＝」演算子を高速化したい場合、別のインデックスを追加する必要があります。

```Sql
sample=# create index idx_btree on t_hash (md5);
CREATE INDEX
```

等価比較の場合は btree が高速です

```sql
sample=# select * from t_hash where md5 = 'dadb4b54e2345679a8861ab52e4128ea';
    id    |               md5
----------+----------------------------------
 37211731 | dadb4b54e2345679a8861ab52e4128ea
(1 row)

Time: 14.403 ms
```
