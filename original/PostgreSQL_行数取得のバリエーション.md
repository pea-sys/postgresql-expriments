# テーブル行数推定

## Motivation

概算値で良いので行数取得クエリを早くしたい。  
Redis の HyperLogLog みたいなものが Postgresql にもないかなと思い探しました。

## Conclusion

| 方法          | `where`句の使用 | 事前 `vacuum` | 精度                          | 速度(1 億行) | 速度(2 億行) |
| ------------- | --------------- | ------------- | ----------------------------- | ------------ | ------------ |
| `count(*)`    | 可              | 不要          | 正確                          | 3.5 秒       | 13 秒        |
| `TABLESAMPLE` | 可              | 不要          | 不正確                        | 0.1 秒       | 1 秒         |
| タプルサイズ  | 不可            | 必要          | 不正確(`vacuum` の頻度による) | 1 秒         | 1 秒         |
| `explain`     | 可              | 不要          | 不正確(`vacuum` の頻度による) | 0.005 秒     | 0.005 秒     |

※不正確な精度にも程度の差はあると思いますが、そこはリサーチ出来ていません。
許容できる速度に応じて使い分けると良いと思います。
一見すると explain が良さそうなのですが、内部処理は複雑です。
安易な採用は止めた方が良いでしょう。
採用する場合には、自動バキュームやアナライズの頻度を事前に確認しておいた方が良いです。

## Setup

データベースを準備します。

```
root@masami-L ~# sudo -i -u postgres
postgres@masami-L:~$ createdb -U postgres sample
postgres@masami-L:~$ psql -U postgres -d sample
sample=# create schema myschema;
CREATE SCHEMA
Time: 4.479 ms
```

データを作成します。

```sql
sample=# \timing
Timing is on.
sample=# create table myschema.sample as select id from generate_series(1, 200000000) as id;
SELECT 200000000
Time: 327569.167 ms (05:27.569)
```

## `COUNT(*)`

行数取得の一般的な方法です。  
対象列の指定は\*でも最適化されるので問題ありません。  
速度は遅いが正確な値が得られます。  
`where`句で動的に抽出対象が変更出来ます。  
テーブルサイズが大きいと遅い問題があります。

```Sql
sample=# select count(*) from myschema.sample;
   count
-----------
 200000000
(1 row)

Time: 13130.963 ms (00:13.131)
```

## `TABLESAMPLE`

テーブルから 1%の行数を取得後、100 倍します。  
テーブルサイズの影響を大幅に軽減できます。

```sql
sample=# select 100 * count(*) AS estimate FROM myschema.sample TABLESAMPLE SYSTEM (1);
 estimate
-----------
 197411000
(1 row)

Time: 1701.041 ms (00:01.701)
```

精度を上げたい場合は、サンプル数を増やしてもいいですが、実行速度と精度はトレードオフの関係にあります

```sql
sample=# select 20 * count(*) AS estimate FROM myschema.sample TABLESAMPLE SYSTEM (5);
 estimate
-----------
 199011080
(1 row)

Time: 5987.922 ms (00:05.988)

sample=# select 10 * count(*) AS estimate FROM myschema.sample TABLESAMPLE SYSTEM (10);
 estimate
-----------
 199420140
(1 row)

Time: 19061.065 ms (00:19.061)
```

## カタログテーブル `pg_class`から算出

カタログテーブルから行数を得る方法です。  
速度は速いですが概算値になります。  
他の方法と異なり、フィルターや結合が使えません。  
また、テーブル作成後に `vacuum` が一度も動いていないと空を返します。  
動的パーティションテーブルを対象とする場合、使いづらいかもしれません。

よく見かけるクエリですが、`vacuum` 前だとエラーになります。

```sql
sample=# SELECT (reltuples / relpages * (pg_relation_size(oid) / 8192))::bigint
FROM   pg_class
WHERE  oid = 'myschema.sample'::regclass;
ERROR:  division by zero
Time: 0.793 ms
```

厳密なクエリ。エラーは出ませんが `vacuum`前だと空を返します。

```Sql
sample=# SELECT (CASE WHEN c.reltuples < 0 THEN NULL       -- never vacuumed
             WHEN c.relpages = 0 THEN float8 '0'  -- empty table
             ELSE c.reltuples / c.relpages END
     * (pg_catalog.pg_relation_size(c.oid)
      / pg_catalog.current_setting('block_size')::int)
       )::bigint
FROM   pg_catalog.pg_class c
WHERE  c.oid = 'myschema.sample'::regclass;
 int8
------

(1 row)

Time: 0.437 ms
```

1 回でも `vacuum` が動けば取得できるようになります。

```sql
sample=# SELECT (CASE WHEN c.reltuples < 0 THEN NULL       -- never vacuumed
             WHEN c.relpages = 0 THEN float8 '0'  -- empty table
             ELSE c.reltuples / c.relpages END
     * (pg_catalog.pg_relation_size(c.oid)
      / pg_catalog.current_setting('block_size')::int)
       )::bigint
FROM   pg_catalog.pg_class c
WHERE  c.oid = 'myschema.sample'::regclass;
   int8
-----------
 199999936
(1 row)

Time: 1.239 ms
```

## `explain`で推定

`explain` で推定した行を使用する方法  
概算値ですが、フィルターや結合が使えて早い。
精度は、条件を複雑にすればするほど不正確になるようです。

```sql
sample=# create function row_estimator(query text) returns bigint
language plpgsql as
$$declare
plan jsonb;
begin
execute 'explain (format json) ' || query into plan;
return (plan->0->'Plan'->>'Plan Rows')::bigint;
end;$$;
CREATE FUNCTION
```

```sql
sample=# select row_estimator('select * from myschema.sample');
 row_estimator
---------------
     225663780
(1 row)

Time: 5.918 ms
```

[参考ページ]

- [CYBERTEC ブログ](https://www.cybertec-postgresql.com/en/postgresql-count-made-fast/)
- [数の推定](https://wiki.postgresql.org/wiki/Count_estimate)
- [Fast way to discover the row count of a table in PostgreSQL](https://stackoverflow.com/questions/7943233/fast-way-to-discover-the-row-count-of-a-table-in-postgresql)
- [Out of Range statistics with PostgreSQL & YugabyteDB](https://dev.to/yugabyte/out-of-range-statistics-with-postgresql-yugabytedb-2pj8)

以上。
