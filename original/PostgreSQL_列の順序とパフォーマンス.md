# 列の順序とパフォーマンス

次の記事のトレースです

https://www.cybertec-postgresql.com/en/column-order-in-postgresql-does-matter/

カラム順がデータサイズに影響があることは知っていたので、それのことかなと思っていましたが、もっと別の視点でパフォーマンスに関する内容でした。

### 準備

DB 作成

```
postgres@masami-L:createdb -U postgres sample
postgres@masami-L:/$ psql -U postgres -d sample
```

テーブル作成

```sql
sample=# select 'create table t_broad ('
|| string_agg('t_' || x
|| ' varchar(10) default ''a'' ', ', ')
|| ' )'
from generate_series(1, 4) as x;
sample=# \gexec
CREATE TABLE
```

ここではお試しで４つの列を作成しました。  
もっと大きいテーブルを作成するので削除します。

```sql
sample=# drop table t_broad;
DROP TABLE
```

1500 の列を持つテーブルを作成

```Sql
sample=# select 'create table t_broad ('
|| string_agg('t_' || x
|| ' varchar(10) default ''a'' ', ', ') || ' )'
from generate_series(1, 1500) as x; \gexec
CREATE TABLE
```

### データ作成

100 万行を追加します

```sql
sample-# select 'a' from generate_series(1, 1000000);
INSERT 0 1000000
Time: 121121.149 ms (02:01.121)
sample=# vacuum analyze;
VACUUM
Time: 170496.453 ms (02:50.496)
```

テーブルサイズは 4GB です

```sql
sample=# select pg_size_pretty(pg_total_relation_size('t_broad'));
 pg_size_pretty
----------------
 3907 MB
(1 row)

Time: 2.393 ms
```

### さまざまな列へのアクセス

全ての列に並列シーケンシャルスキャンします

```sql
sample=# select count(*) from t_broad;
  count
---------
 1000000
(1 row)

Time: 1131.567 ms (00:01.132)
sample=# explain select count(*) from t_broad;
                                         QUERY PLAN
--------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=506208.55..506208.56 rows=1 width=8)
   ->  Gather  (cost=506208.33..506208.54 rows=2 width=8)
         Workers Planned: 2
         ->  Partial Aggregate  (cost=505208.33..505208.34 rows=1 width=8)
               ->  Parallel Seq Scan on t_broad  (cost=0.00..504166.67 rows=416667 width=0)
 JIT:
   Functions: 4
   Options: Inlining true, Optimization true, Expressions true, Deforming true
(8 rows)
```

最初の列にアクセスします。  
パフォーマンスはすべての列を指定した場合とほとんど変わりません。

```sql
sample=# select count(t_1) from t_broad;
  count
---------
 1000000
(1 row)

Time: 811.031 ms

```

列番号 100 にアクセスすると 2 倍近く遅くなります

```Sql
sample=# select count(t_100) from t_broad;
  count
---------
 1000000
(1 row)

Time: 1646.089 ms (00:01.646)
```

列番号 1000 にアクセスすると更に顕著に遅くなります

```sql
sample=# select count(t_1000) from t_broad;
  count
---------
 1000000
(1 row)

Time: 13889.034 ms (00:13.889)
```

### 問題を暴く

パフォーマンスに影響を与えているので列の位置を割り出しです。  
int の場合は、固定サイズなので位置割り出しは容易ですが、varchar のような可変サイズの場合は困難になります。  
列番号 1000 にアクセスするためには、列番号 999 までの長さを計算する必要があります。  
varchar のサイズを計算するには次の要素を考慮する必要があります。

- 1 ビットは短い文字列 (127 バイト) と長い文字列 (> 127 ビット) を示します
- 7 ビットまたは 31 ビットの長さ (最初のビットに応じて)
- “data” + \0 (文字列を終了するため)
- アラインメント (次の列が CPU ワード長の倍数で始まるようにするため)

### おまけ

固定列で 1 番目と 1000 番目の列にアクセスした際のパフォーマンスを確認します。

```sql
sample=# select 'create table t_broad ('
|| string_agg('t_' || x
|| ' smallint default 0 ', ', ') || ' )'
from generate_series(1, 1500) as x; \gexec
Time: 2.147 ms
CREATE TABLE
Time: 131.839 ms
Time: 1.137 ms
sample=# insert into t_broad
select 1 from generate_series(1, 1000000);
INSERT 0 1000000
Time: 101132.338 ms (01:41.132)
sample=# vacuum analyze;
VACUUM
Time: 20971.066 ms (00:20.971)
```

```sql
sample=# select count(t_1) from t_broad;
  count
---------
 1000000
(1 row)

Time: 812.472 ms
sample=# select count(t_1000) from t_broad;
  count
---------
 1000000
(1 row)

Time: 7034.414 ms (00:07.034)
```

varchar 程ではないですが 9 倍程度の差が出ています。

同様に numeric で差を調べてみましたが、可変型なのに smallint よりもギャップが少なかったです。

```sql
sample=# select 'create table t_broad ('
|| string_agg('t_' || x
|| ' numeric(31) default 0 ', ', ') || ' )'
from generate_series(1, 1500) as x; \gexec
Time: 1.737 ms
CREATE TABLE
Time: 133.405 ms
Time: 1.074 ms
sample=# insert into t_broad
select 1.0 from generate_series(1, 1000000);
INSERT 0 1000000
Time: 193714.612 ms (03:13.715)
sample=# vacuum analyze;

VACUUM
Time: 239662.305 ms (03:59.662)
sample=#
sample=# select count(t_1) from t_broad;
  count
---------
 1000000
(1 row)

Time: 16762.413 ms (00:16.762)
sample=# select count(t_1000) from t_broad;
  count
---------
 1000000
(1 row)

Time: 25966.023 ms (00:25.966)
```
