# EXPLAIN出力でバッファ統計を読み取る

次の記事のトレースです
https://boringsql.com/posts/explain-buffers/

PostgreSQLは各プランノードのバッファ使用量を内訳しており、これらの数値の読み方を学べば、クエリがI/O待ちに時間を費やした場所と、待つ必要がなかった場所を正確に把握できます。これは、パフォーマンスの問題を診断する際に最も基本的なことです。

## 例

- データベース作成

```
C:\Users\masami>createdb -U postgres sample

C:\Users\masami>psql -U postgres -d sample
ユーザー postgres のパスワード:

psql (18.1)
"help"でヘルプを表示します。
```

- データ準備

```sql
sample=# CREATE TABLE customers (
sample(#     id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
sample(#     name text NOT NULL
sample(# );
CREATE TABLE
sample=#
sample=# CREATE TABLE orders (
sample(#     id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
sample(#     customer_id integer NOT NULL REFERENCES customers(id),
sample(#     amount numeric(10,2) NOT NULL,
sample(#     status text NOT NULL DEFAULT 'pending',
sample(#     note text,
sample(#     created_at date NOT NULL DEFAULT CURRENT_DATE
sample(# );
CREATE TABLE
sample=#
sample=# INSERT INTO customers (name)
sample-# SELECT 'Customer ' || i
sample-# FROM generate_series(1, 2000) AS i;
INSERT 0 2000
sample=#
sample=# -- seed data: ~100,000 orders spread across 2022-2025
sample=# INSERT INTO orders (customer_id, amount, status, note, created_at)
sample-# SELECT
sample-#     (random() * 1999 + 1)::int,
sample-#     (random() * 500 + 5)::numeric(10,2),
sample-#     (ARRAY['pending','shipped','delivered','cancelled'])[floor(random()*4+1)::int],
sample-#     CASE WHEN random() < 0.3 THEN 'Some note text here for padding' ELSE NULL END,
sample-#     '2022-01-01'::date + (random() * 1095)::int  -- ~3 years of data
sample-# FROM generate_series(1, 100000);
INSERT 0 100000
sample=#
sample=# -- make sure stats are up to date
sample=# ANALYZE customers;
ANALYZE
sample=# ANALYZE orders;
ANALYZE
sample=#
sample=# -- we are going to skip indexes on purpose
sample=#
sample=# -- and fire sample query
sample=# select count(1) from customers;
 count
-------
  2000
(1 行)
```

簡単なサンプル

```sql
sample=# EXPLAIN (ANALYZE, BUFFERS)
sample-# SELECT o.*, c.name
sample-# FROM orders o
sample-# JOIN customers c ON o.customer_id = c.id
sample-# WHERE o.created_at > '2024-01-01';
                                                         QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------
 Hash Join  (cost=58.00..2250.96 rows=33437 width=71) (actual time=1.085..34.531 rows=33359.00 loops=1)
   Hash Cond: (o.customer_id = c.id)
   Buffers: shared hit=868
   ->  Seq Scan on orders o  (cost=0.00..2105.00 rows=33437 width=58) (actual time=0.035..20.304 rows=33359.00 loops=1)
         Filter: (created_at > '2024-01-01'::date)
         Rows Removed by Filter: 66641
         Buffers: shared hit=855
   ->  Hash  (cost=33.00..33.00 rows=2000 width=17) (actual time=0.669..0.670 rows=2000.00 loops=1)
         Buckets: 2048  Batches: 1  Memory Usage: 118kB
         Buffers: shared hit=13
         ->  Seq Scan on customers c  (cost=0.00..33.00 rows=2000 width=17) (actual time=0.013..0.284 rows=2000.00 loops=1)
               Buffers: shared hit=13
 Planning:
   Buffers: shared hit=93
 Planning Time: 6.639 ms
 Execution Time: 36.124 ms
(16 行)
```

### Shared buffers: hit, read, dirtied & written

shared hit:共有バッファ（つまりキャッシュ）内で見つかったページ数です。これはディスクI/Oを必要としない高速パスです。値が大きいほどパフォーマンスが向上します。

shared read:ディスク (または OS キャッシュ) から取得され、共有バッファーにないページの数を識別します。各ページは、潜在的な I/O レイテンシを追加します。

shared written:このクエリによって変更されたページ数が含まれています。クエリによって、既にキャッシュされているデータ（バッファプール内）が変更されたため、これらのページは最終的にディスクに書き込む必要があります。

shared written:クエリ実行中にディスクに書き込まれたページ数です。これは、クエリがバッファスペースを必要としているものの、ダーティページを同期的に削除する必要があるときに発生します。SELECT文の実行中にこの値が繰り返し表示される場合は、バックグラウンドライターが正常に処理できていないという警告サインかもしれません。

Explainの結果を見ると全て共有バッファから取得できています。

```
Buffers: shared hit=868
```

アクセスしたばかりのページであるため、全てキャッシュされていたようです。

### ローカルバッファ

ローカルバッファ(temp_buffers)は、一時テーブルのI/Oを追跡します。共有バッファに格納される通常のテーブルとは異なり、一時テーブルはバックエンドごとにメモリを使用します。つまり、各接続は設定によって制御される独自のローカルバッファプールを取得します

```sql
sample=# CREATE TEMP TABLE temp_large_orders AS
sample-# SELECT o.id, o.amount, o.status, o.created_at, c.name AS customer_name
sample-# FROM orders o
sample-# JOIN customers c ON o.customer_id = c.id
sample-# WHERE o.amount > 200;
SELECT 61274
sample=#
sample=# EXPLAIN (ANALYZE, BUFFERS)
sample-# SELECT status, count(*), sum(amount)
sample-# FROM temp_large_orders
sample-# GROUP BY status;
                                                          QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------
 HashAggregate  (cost=1281.60..1284.10 rows=200 width=72) (actual time=34.617..34.620 rows=4.00 loops=1)
   Group Key: status
   Batches: 1  Memory Usage: 32kB
   Buffers: local hit=576
   ->  Seq Scan on temp_large_orders  (cost=0.00..979.20 rows=40320 width=48) (actual time=0.027..6.579 rows=61274.00 loops=1)
         Buffers: local hit=576
 Planning:
   Buffers: shared hit=41
 Planning Time: 15.411 ms
 Execution Time: 34.710 ms
(10 行)
```

報告される可能性のある個々の値は、共有と同じ概念のローカル ヒット/読み取りですが、バックエンドごとのバッファー プール内の一時テーブルが対象となります。

もう1つの値は、一時テーブルの変更を表すローカルの「ダーティ/書き込み」です。「ダーティ」とは、クエリによってローカルバッファプール内のページが変更されたことを意味します。「書き込み」とは、新しいページのためのスペースを確保するために、ダーティページをディスクにフラッシュする必要があったことを意味します。これは、共有バッファと同じクロックスイープによる排除メカニズムですが、ローカルバッファプールに対して行われます。共有バッファとは異なり、一時テーブルへの書き込みはWALを生成せず、チェックポイントの対象にもなりません。

実際には、local writtenはめったに見られません。PostgreSQL は、一時テーブルのオーバーフローを非常に効率的に処理するため、temp_buffers一時テーブルのワークロードに比べて大幅にサイズが小さい場合を除き、この問題が発生する可能性は低くなります。

## work_memが足りない場合

ローカル バッファはそれほど問題とはみなされず、目に見えることもあまりありませんが、一時バッファは、ソート、ハッシュ、および現在のwork_mem設定を超えるその他の操作がメモリからディスクに流出するケースを追跡します。

```sql
sample=# SET work_mem = '256kB';
SET
sample=#
sample=# EXPLAIN (ANALYZE, BUFFERS)
sample-# SELECT o.id, o.amount, o.status, o.created_at, c.name
sample-# FROM orders o
sample-# JOIN customers c ON o.customer_id = c.id
sample-# ORDER BY o.amount DESC;
                                                            QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=13687.08..13937.08 rows=100000 width=35) (actual time=153.075..170.388 rows=100000.00 loops=1)
   Sort Key: o.amount DESC
   Sort Method: external merge  Disk: 4864kB
   Buffers: shared hit=871, temp read=1820 written=1862
   ->  Hash Join  (cost=58.00..2176.06 rows=100000 width=35) (actual time=0.551..38.627 rows=100000.00 loops=1)
         Hash Cond: (o.customer_id = c.id)
         Buffers: shared hit=868
         ->  Seq Scan on orders o  (cost=0.00..1855.00 rows=100000 width=26) (actual time=0.032..5.535 rows=100000.00 loops=1)
               Buffers: shared hit=855
         ->  Hash  (cost=33.00..33.00 rows=2000 width=17) (actual time=0.509..0.510 rows=2000.00 loops=1)
               Buckets: 2048  Batches: 1  Memory Usage: 118kB
               Buffers: shared hit=13
               ->  Seq Scan on customers c  (cost=0.00..33.00 rows=2000 width=17) (actual time=0.011..0.223 rows=2000.00 loops=1)
                     Buffers: shared hit=13
 Planning:
   Buffers: shared hit=18
 Planning Time: 3.804 ms
 Execution Time: 190.126 ms
(18 行)
```

ディスク上の一時ファイルから読み書きされたページ数と、一時ファイルの読み取り/書き込み数が表示されます。これは、操作がメモリに収まらなかったことを示しています。

```
Buffers: shared hit=871, temp read=1820 written=1862
```

Sort Method: external merge Disk: 9736kB20万行をわずか256KBのwork_memメモリでソートすると、PostgreSQLはディスク上の一時ファイルに約4.3MBを吐き出さざるを得なくなります。これはソートtemp written=3722フェーズでページがフラッシュアウトされた際に発生し、マージフェーズではPostgreSQLがそれらを読み戻して最終的なソート結果を生成する際にも発生しました。

バッファは全く表示されませんtemp。ソートはメモリ内で完了し、実行時間は短縮され、I/Oはテーブルデータの読み取りのみでした。

```sql
sample=# SET work_mem = '16MB';
SET
sample=# EXPLAIN (ANALYZE, BUFFERS)
sample-# SELECT o.id, o.amount, o.status, o.created_at, c.name
sample-# FROM orders o
sample-# JOIN customers c ON o.customer_id = c.id
sample-# ORDER BY o.amount DESC;
                                                            QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=10480.88..10730.88 rows=100000 width=35) (actual time=108.415..119.796 rows=100000.00 loops=1)
   Sort Key: o.amount DESC
   Sort Method: quicksort  Memory: 8907kB
   Buffers: shared hit=868
   ->  Hash Join  (cost=58.00..2176.06 rows=100000 width=35) (actual time=1.212..49.806 rows=100000.00 loops=1)
         Hash Cond: (o.customer_id = c.id)
         Buffers: shared hit=868
         ->  Seq Scan on orders o  (cost=0.00..1855.00 rows=100000 width=26) (actual time=0.026..7.371 rows=100000.00 loops=1)
               Buffers: shared hit=855
         ->  Hash  (cost=33.00..33.00 rows=2000 width=17) (actual time=1.169..1.172 rows=2000.00 loops=1)
               Buckets: 2048  Batches: 1  Memory Usage: 118kB
               Buffers: shared hit=13
               ->  Seq Scan on customers c  (cost=0.00..33.00 rows=2000 width=17) (actual time=0.012..0.483 rows=2000.00 loops=1)
                     Buffers: shared hit=13
 Planning:
   Buffers: shared hit=6
 Planning Time: 0.407 ms
 Execution Time: 125.473 ms
(18 行)
```

一時ファイルの使用量を減らすには、次の方法があります。

- work_mem増加(注意: これはクエリごとではなく操作ごとの設定であることを忘れないでください。複数のソートやハッシュ結合を含む複雑なクエリでは、work_memそれぞれに割り当てられます)
- ソート前に処理する行数を減らすようにクエリを最適化します
- そしておそらく最も重要なのは、ソートを完全に回避するためにインデックスを追加することを検討することです。インデックスを追加するとorders(amount DESC)ソートノードが完全に削除されます。

### バッファの計画

PostgreSQL 13から追加された機能で、クエリ実行とは別に、クエリ計画中のバッファ使用量を確認できるようになりました。

```
 Planning:
   Buffers: shared hit=6
```

多くのテーブルにアクセスする複雑なクエリはプランニング時のI/Oに重大な影響を与える可能性があります。

計画フェーズでのread数が多い場合、システム カタログがキャッシュされていない (コールド スタートの可能性が最も高い) か、クエリが多数のテーブルまたは列にアクセスしていることが示唆されます。

プランニング時間が問題となる場合は、システムカタログが常にホットな状態であることを確認してください。パーティションが多数存在するシステムでは、プランニングのオーバーヘッドが大きくなる可能性があります。これがパーティションプルーニングが重要な理由の一つです。

## 計画バッファと実行バッファの曖昧な境界線

PostgreSQLは実際には、計画フェーズですべてのメタデータを解決するわけではありません。プランナーは最適な計画を選択するために必要な最小限の作業を行いますが、一部のカタログ検索は実行時に延期されます。

## まとめ

すべてのバッファ カテゴリにわたって問題が発生したクエリのサンプル出力を次に示します。

```
 Buffers: shared hit=50 read=15000 written=847
          temp read=2500 written=2500
 Planning:
   Buffers: shared hit=12 read=156
 Planning Time: 45.678 ms
 Execution Time: 12345.678 ms
```

これを隅から隅まで読んでいくと、ヒット率が非常に低い（50ヒットに対して15,000回の読み取り）ため、ワーキングセットがキャッシュされていないことがわかります。これは、クエリが同期的なエビクション(written=847)を強制したことを意味します。つまり、バックグラウンドライターが追いつけないということです。一時データ流出は、操作が を超えたことを示しています。プランニングでさえ156回の読み取りが必要だったため、システムカタログがキャッシュからエビクションされたと考えられます。

## 単一のクエリを超えて

単一のクエリ分析は便利ですが、ワークロード全体のパターンの方が重要です。
時間の経過に伴って集計された同じバッファー カウンターを公開します。

```sql
SELECT
    substring(query, 1, 60) AS query,
    calls,
    shared_blks_hit,
    shared_blks_read,
    round(100.0 * shared_blks_hit /
      nullif(shared_blks_hit + shared_blks_read, 0), 2) AS hit_pct,
    temp_blks_written
FROM pg_stat_statements
WHERE calls > 100
ORDER BY shared_blks_read DESC
LIMIT 10;
```

これにより、システム全体で最も多くのディスク読み取りを引き起こしているクエリが示されます。多くの場合、一度に 1 つのクエリを分析するよりも実用的な方法となります。
