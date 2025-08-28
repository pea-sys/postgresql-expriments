# 複合インデックスと部分インデックスを使用した PostgreSQL の最適化 簡単な比較

こちらの記事のトレースです  
元記事に加えて、データ生成クエリ等を追記しています

https://stormatics.tech/blogs/optimizing-postgresql-with-composite-and-partial-indexes

## 複合インデックス

複合インデックスは複数の列に作成され、PostgreSQL が検索条件に複数の列を含むクエリを効率的に処理できるようにします。このタイプのインデックスは、クエリが複数のフィールドを使用してデータを頻繁にフィルタリングまたは並べ替える場合に特に役立ちます。

テスト用 DB 作成

```
createdb -U postgres sample

psql -U postgres sample
psql (16.4 (Ubuntu 16.4-1.pgdg24.04+1))
Type "help" for help.
```

テーブル定義

```sql
sample=# CREATE TABLE public.sales (
    sale_id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    customer_id integer NOT NULL,
    product_id integer NOT NULL,
    sale_date date NOT NULL,
    amount numeric(10,2) NOT NULL
);
CREATE TABLE
```

データ投入

```sql
insert into
  public.sales (customer_id, product_id, sale_date, amount)
select
  (random() * 1000)::integer + 1 as customer_id,
  (random() * 100)::integer + 1 as product_id,
  (current_date - (random() * 365)::integer) as sale_date,
  (random() * 1000)::numeric(10, 2) as amount
from
  generate_series(1, 1000000);
```

複数カラムを検索条件に指定すると、並列シーケンシャルスキャンします。

```sql
sample=# EXPLAIN ANALYZE SELECT * FROM sales WHERE product_id = 408 AND sale_date = '2024-08-17';
                                                     QUERY PLAN
---------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..14603.35 rows=12 width=26) (actual time=47.106..52.137 rows=0 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on sales  (cost=0.00..13602.15 rows=5 width=26) (actual time=42.978..42.979 rows=0 loops=3)
         Filter: ((product_id = 408) AND (sale_date = '2024-08-17'::date))
         Rows Removed by Filter: 333333
 Planning Time: 0.087 ms
 Execution Time: 52.171 ms
(8 rows)
```

複合インデックスを作成します

```sql
CREATE INDEX idx_sales_product_id_sale_date ON sales(product_id, sale_date);
CREATE INDEX
```

複数カラムを検索条件に指定すると、インデックスキャンが使われるようになりました  
実行速度も 30 倍以上速くなりました

```sql
EXPLAIN ANALYZE SELECT * FROM sales WHERE product_id = 408 AND sale_date = '2024-08-17';
                                                               QUERY PLAN                                              >
----------------------------------------------------------------------------------------------------------------------->
 Bitmap Heap Scan on sales  (cost=4.57..58.95 rows=14 width=26) (actual time=1.505..1.506 rows=0 loops=1)
   Recheck Cond: ((product_id = 408) AND (sale_date = '2024-08-17'::date))
   ->  Bitmap Index Scan on idx_sales_product_id_sale_date  (cost=0.00..4.56 rows=14 width=0) (actual time=1.446..1.446>
         Index Cond: ((product_id = 408) AND (sale_date = '2024-08-17'::date))
 Planning Time: 1.080 ms
 Execution Time: 1.547 ms
(6 rows)
```

## 部分インデックス

部分インデックスは、テーブル内のすべての行を対象とするのではなく、特定の条件を満たすデータのサブセットのみをインデックスします。部分インデックスは、特定のデータのサブセットをターゲットにすることで、ストレージのニーズを減らし、クエリのパフォーマンスを向上させることができます。

テーブル作成

```sql
CREATE TABLE IF NOT EXISTS covid_data ( id SERIAL PRIMARY KEY, country varchar(20), title varchar(10), names varchar(20), vaccinated varchar(3) );
CREATE TABLE
```

データ挿入

```Sql
INSERT INTO covid_data (country, title, names, vaccinated)
SELECT
(ARRAY['USA', 'Canada', 'UK', 'Germany', 'France', 'India', 'China', 'Brazil', 'Australia', 'Japan'])[floor(random() * 10 + 1)],
(ARRAY['Mr.', 'Ms.', 'Dr.', 'Prof.'])[floor(random() * 4 + 1)],
(ARRAY['John', 'Jane', 'Alex', 'Emily', 'Michael', 'Sarah', 'David', 'Laura', 'Robert', 'Linda'])[floor(random() * 10 + 1)],
CASE
  WHEN random() < 0.8 THEN 'Yes'
  ELSE 'No'
END
FROM generate_series(1, 3000000);
INSERT 0 3000000
```

部分インデックスなしで検索

```sql
EXPLAIN ANALYZE SELECT * FROM covid_data WHERE vaccinated = 'Yes' AND country = 'UK' AND title = 'Prof.';
                                                            QUERY PLAN                                                 >
----------------------------------------------------------------------------------------------------------------------->
 Gather  (cost=1000.00..49485.20 rows=59072 width=23) (actual time=1.591..600.799 rows=59552 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on covid_data  (cost=0.00..42578.00 rows=24613 width=23) (actual time=0.839..486.281 rows=1985>
         Filter: (((vaccinated)::text = 'Yes'::text) AND ((country)::text = 'UK'::text) AND ((title)::text = 'Prof.'::t>
         Rows Removed by Filter: 980149
 Planning Time: 4.793 ms
 Execution Time: 604.517 ms
(8 rows)
```

通常のインデックスを作成

```Sql
sample=# CREATE INDEX vaccinated_full_idx ON covid_data(vaccinated);
CREATE INDEX
sample=# CREATE INDEX country_full_idx ON covid_data(country);
CREATE INDEX
sample=# CREATE INDEX title_full_idx ON covid_data(title);
CREATE INDEX
```

インデックスありで検索

```sql
EXPLAIN ANALYZE SELECT * FROM covid_data WHERE vaccinated = 'Yes' AND country = 'UK' AND title = 'Prof.';
                                                               QUERY PLAN                                              >
----------------------------------------------------------------------------------------------------------------------->
 Bitmap Heap Scan on covid_data  (cost=3262.20..29180.20 rows=59072 width=23) (actual time=15.720..398.969 rows=59552 l>
   Recheck Cond: ((country)::text = 'UK'::text)
   Filter: (((vaccinated)::text = 'Yes'::text) AND ((title)::text = 'Prof.'::text))
   Rows Removed by Filter: 239831
   Heap Blocks: exact=20703
   ->  Bitmap Index Scan on country_full_idx  (cost=0.00..3247.43 rows=298000 width=0) (actual time=11.803..11.804 rows>
         Index Cond: ((country)::text = 'UK'::text)
 Planning Time: 1.401 ms
 Execution Time: 401.655 ms
(9 rows)
```

30%位速くなりました。インデックスサイズは下記の通り。

```sql
sample=# SELECT pg_size_pretty(pg_relation_size('title_full_idx'));
 pg_size_pretty
----------------
 20 MB
(1 row)

sample=# SELECT pg_size_pretty(pg_relation_size('country_full_idx'));
 pg_size_pretty
----------------
 20 MB
(1 row)

sample=# SELECT pg_size_pretty(pg_relation_size('vaccinated_full_idx'));
 pg_size_pretty
----------------
 20 MB
(1 row)
```

部分インデックスを作成します

```sql
CREATE INDEX vaccinated_pa​​rtial_idx ON covid_data(vaccinated) WHERE vaccinated = 'Yes' AND country = 'UK' AND title = 'Prof.';
CREATE INDEX
```

再度同じクエリを実行します

```sql
EXPLAIN ANALYZE SELECT * FROM covid_data WHERE vaccinated = 'Yes' AND country = 'UK' AND title = 'Prof.';
                                                                QUERY PLAN                                             >
----------------------------------------------------------------------------------------------------------------------->
 Bitmap Heap Scan on covid_data  (cost=522.42..22259.18 rows=59072 width=23) (actual time=6.286..113.505 rows=59552 loo>
   Recheck Cond: (((vaccinated)::text = 'Yes'::text) AND ((country)::text = 'UK'::text) AND ((title)::text = 'Prof.'::t>
   Heap Blocks: exact=19544
   ->  Bitmap Index Scan on "vaccinated_pa​​rtial_idx"  (cost=0.00..507.65 rows=59072 width=0) (actual time=3.173..3.174
 >
 Planning Time: 0.164 ms
 Execution Time: 115.512 ms
(6 rows)
```

フルインデックス使用時の倍以上の速度になりました。また、インデックスサイズも小さいです。

```sql
 SELECT pg_size_pretty(pg_relation_size('vaccinated_pa​​rtial_idx'));
 pg_size_pretty
----------------
 424 kB
(1 row)
```
