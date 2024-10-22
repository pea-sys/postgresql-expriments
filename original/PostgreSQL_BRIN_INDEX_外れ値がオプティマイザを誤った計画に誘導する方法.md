# 外れ値がオプティマイザを誤った計画に誘導する方法

こちらの記事をトレースします

https://hakibenita.com/postgresql-correlation-brin-multi-minmax

ブロック範囲インデックス (BRIN) を使用して相関関係の高いフィールドをクエリすることは、オプティマイザーにとって簡単な選択です。インデックスのサイズが小さく、フィールドの相関関係が高いため、BRIN は理想的な選択です。しかし、相関関係は誤解を招く可能性があることがわかりました。簡単に再現できる状況では、インデックス付けされたフィールドの相関関係が非常に高い場合でも、BRIN インデックスによって実行速度が大幅に低下する可能性があります。

```
createdb -U postgres sample
psql -U postgres -d sample
```

### 相関

相関は、値の論理的な順序とテーブル内の物理的な位置との間の係数です。たとえば、追加専用のテーブルでは、自動増分キーの相関は 1 で完璧です。ただし、ランダムな値の相関は非常に低く、0 に近い値になります。

時系列データを持つテーブルを作成します

```Sql
CREATE OR REPLACE FUNCTION generate_random_string(
  length INTEGER,
  characters TEXT default '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
) RETURNS TEXT AS
$$
DECLARE
  result TEXT := '';
BEGIN
  IF length < 1 then
      RAISE EXCEPTION 'Invalid length';
  END IF;
  FOR __ IN 1..length LOOP
    result := result || substr(characters, floor(random() * length(characters))::int + 1, 1);
  end loop;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

sample=# SET time zone UTC;
SET
sample=# SELECT setseed(0.4050);
 setseed
---------

(1 行)


sample=# CREATE TABLE t (
sample(#     id int,
sample(#     happened_at timestamptz,
sample(#     padding text
sample(# );
CREATE TABLE

sample=# INSERT INTO t (
sample(#     id,
sample(#     happened_at,
sample(#     padding
sample(# )
sample-# SELECT
sample-#     n,
sample-#     '2023-01-01 UTC'::timestamptz + (interval '1 second' * n),
sample-#     generate_random_string(1000)
sample-# FROM
sample-#     generate_series(1, 1000000) as n;
INSERT 0 1000000
```

ベンチマークをより現実的にするために、テーブルにパディングを追加します。

```sql
sample=# SELECT count(*), max(happened_at) FROM t;
  count  |          max
---------+------------------------
 1000000 | 2023-01-12 13:46:40+00
(1 行)
```

```sql
sample=# ANALYZE t;
ANALYZE
sample=# SELECT correlation
sample-# FROM pg_stats
sample-# WHERE tablename = 't'
sample-# AND attname = 'happened_at';
 correlation
-------------
           1
(1 行)
```

フィールドの相関は 1 です。これは、テーブル内の happened_at 列の値の物理的な順序と論理的な順序の間に完全な相関があることを意味します

ベースラインを確立するには、テーブルにインデックスがない状態で 1 分間に発生した値を検索するクエリを実行します。

```Sql
sample=# EXPLAIN (ANALYZE)
sample-# SELECT * FROM t WHERE happened_at BETWEEN '2023-01-12 13:45:00 UTC' AND '2023-01-12 13:46:00 UTC';
                                                                          QUERY PLAN

---------------------------------------------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..150108.14 rows=1 width=1016) (actual time=592.804..610.333 rows=61 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on t  (cost=0.00..149108.04 rows=1 width=1016) (actual time=518.722..518.747 rows=20 loops=3)
         Filter: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
         Rows Removed by Filter: 333313
 Planning Time: 0.459 ms
 Execution Time: 611.085 ms
(8 行)
```

### 完全な相関関係を持つ BRIN 指数

相関関係についての別の考え方は、値の範囲を検索するときに、近似値を持つ行が同じブロックまたは隣接するブロックにある可能性が非常に高いということです。この機能は、ドキュメントで強調されているように、BRIN インデックスにとって非常に重要です。

```Sql
sample=# CREATE INDEX t_happened_at_brin_minmax ON t
sample-# USING brin(happened_at) WITH (pages_per_range=10);
CREATE INDEX
```

BRIN インデックスは非可逆インデックスであるため、その主な利点の 1 つはサイズが小さいことです。
インデックスのサイズはわずか 520 kB です

```sql
sample=#  \di+ t_happened_at_brin_minmax
                                                   リレーション一覧
 スキーマ |           名前            |    タイプ    |  所有者  | テーブル | 永続性 | アクセスメソッド | サイズ | 説明
----------+---------------------------+--------------+----------+----------+--------+------------------+--------+------
 public   | t_happened_at_brin_minmax | インデックス | postgres | t        | 永続   | brin             | 520 kB |
(1 行)
```

BRIN インデックスにより、先のベンチマークの 1%程度の実行速度になりました。

```sql
sample=# EXPLAIN (ANALYZE)
sample-# SELECT * FROM t WHERE happened_at BETWEEN '2023-01-12 13:45:00 UTC' AND '2023-01-12 13:46:00 UTC';
                                                                            QUERY PLAN

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on t  (cost=67.20..145.10 rows=1 width=1016) (actual time=3.271..3.312 rows=61 loops=1)
   Recheck Cond: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
   Rows Removed by Index Recheck: 59
   Heap Blocks: lossy=18
   ->  Bitmap Index Scan on t_happened_at_brin_minmax  (cost=0.00..67.20 rows=70 width=0) (actual time=3.254..3.254 rows=180 loops=1)
         Index Cond: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
 Planning Time: 10.827 ms
 Execution Time: 3.838 ms
(8 行)
```

BRIN インデックスの仕組みをよりよく理解するために、pageinspect 拡張機能を使用して実際のインデックス ブロックの内容を表示することができます。

```Sql
sample=# CREATE EXTENSION pageinspect;
CREATE EXTENSION
sample=# SELECT * FROM brin_metapage_info(get_raw_page('t_happened_at_brin_minmax', 0));
   magic    | version | pagesperrange | lastrevmappage
------------+---------+---------------+----------------
 0xA8109CFA |       1 |            10 |             11
(1 行)
```

インデックス ブロックは lastrevmappage の後から始まります。最初のインデックス ブロックの内容を表示するには、次のブロック (11 + 1 = 12) を調べます。

```sql
sample=# SELECT blknum, value
sample-# FROM brin_page_items(get_raw_page('t_happened_at_brin_minmax', 12), 't_happened_at_brin_minmax')
sample-# ORDER BY 1 LIMIT 3;
 blknum |                       value
--------+----------------------------------------------------
   2910 | {2023-01-01 05:39:31+00 .. 2023-01-01 05:40:40+00}
   2920 | {2023-01-01 05:40:41+00 .. 2023-01-01 05:41:50+00}
   2930 | {2023-01-01 05:41:51+00 .. 2023-01-01 05:43:00+00}
(3 行)
```

最初の行を分解してみましょう。

範囲は 10 個のテーブル ページ (2910 から 2920) で構成されます。これは、pages_per_range インデックスの作成時に指定した値です。
範囲には から 2023-01-01 05:39:31+00 までの値 2023-01-01 05:40:40+00、つまり 70 秒が含まれます。範囲には約 70 行が含まれている必要があります。確認してみましょう。

```sql
sample=# SELECT count(*) FROM t
sample-# WHERE happened_at BETWEEN '2023-01-01 05:39:31+00'::timestamptz AND '2023-01-01 05:40:40+00'::timestamptz;
 count
-------
    70
(1 行)
```

### 外れ値を含む BRIN 指数

これまで、完全な相関関係を持つフィールドで BRIN インデックスを使用してきました。これは BRIN インデックスにとって理想的な状況です。次に、同様のテーブルを作成し、いくつかの外れ値 (フィールドの自然な相関関係に従わない極端な値) を導入します。

```Sql
sample=# CREATE TABLE t_outliers AS
sample-# SELECT
sample-#     id,
sample-#     CASE
sample-#         WHEN id % 70 = 0
sample-#         THEN happened_at + INTERVAL '1 year' -- <-- Outlier
sample-#         ELSE happened_at
sample-#     END,
sample-#     padding
sample-# FROM
sample-#     t
sample-# ORDER BY
sample-#     id;
SELECT 1000000
```

新しいテーブルは、以前のテーブルから作成されます t。外れ値を導入します

```Sql
sample=# SELECT id, happened_at FROM t_outliers ORDER BY id OFFSET 65 LIMIT 10;
 id |      happened_at
----+------------------------
 66 | 2023-01-01 00:01:06+00
 67 | 2023-01-01 00:01:07+00
 68 | 2023-01-01 00:01:08+00
 69 | 2023-01-01 00:01:09+00
 70 | 2024-01-01 00:01:10+00
 71 | 2023-01-01 00:01:11+00
 72 | 2023-01-01 00:01:12+00
 73 | 2023-01-01 00:01:13+00
 74 | 2023-01-01 00:01:14+00
 75 | 2023-01-01 00:01:15+00
(10 行)
```

相関関係を確認します

```sql
sample=# ANALYZE t_outliers;
ANALYZE
sample=# SELECT correlation
sample-# FROM pg_stats
sample-# WHERE tablename = 't_outliers'
sample-# AND attname = 'happened_at';
 correlation
-------------
   0.9731079
(1 行)
```

相関関係はもはや完璧ではありませんが、それでも 0.97 と非常に高いです。通常の状況では、このタイプの相関関係は高いと考えられるため、BRIN インデックスは適切な候補となります。

```sql
sample=# CREATE INDEX t_outliers_happened_at_brin_minmax ON t_outliers
sample-# USING brin(happened_at) WITH (pages_per_range=10);
CREATE INDEX
```

ベンチマークと同じクエリを実行します

```sql
sample=#  EXPLAIN (ANALYZE)
sample-# SELECT * FROM t_outliers
sample-# WHERE happened_at BETWEEN '2023-01-12 13:45:00 UTC' AND '2023-01-12 13:46:00 UTC';
                                                                            QUERY PLAN

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on t_outliers  (cost=67.20..147.32 rows=1 width=1016) (actual time=1374.674..1376.818 rows=60 loops=1)   Recheck Cond: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
   Rows Removed by Index Recheck: 999940
   Heap Blocks: lossy=142858
   ->  Bitmap Index Scan on t_outliers_happened_at_brin_minmax  (cost=0.00..67.20 rows=72 width=0) (actual time=9.288..9.288 rows=1429120 loops=1)
         Index Cond: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
 Planning Time: 2.166 ms
 Execution Time: 1376.868 ms
(8 行)
```

インデックスを張っていないテーブルよりも実行速度が倍以上遅くなりました。
Rows Removed by Index Recheck: 999940 となっており、このクエリは実質的にテーブル全体とインデックスをスキャンしたことになります

BRIN インデックスの内容を調べてみましょう

```sql
sample=# SELECT * FROM brin_metapage_info(get_raw_page('t_outliers_happened_at_brin_minmax', 0));
   magic    | version | pagesperrange | lastrevmappage
------------+---------+---------------+----------------
 0xA8109CFA |       1 |            10 |             11
(1 行)

sample=# SELECT blknum, value
sample-# FROM brin_page_items(get_raw_page('t_outliers_happened_at_brin_minmax', 12), 't_outliers_happened_at_brin_minmax')
sample-# ORDER BY 1 LIMIT 3;
 blknum |                       value
--------+----------------------------------------------------
   2910 | {2023-01-01 05:39:31+00 .. 2024-01-01 05:40:40+00}
   2920 | {2023-01-01 05:40:41+00 .. 2024-01-01 05:41:50+00}
   2930 | {2023-01-01 05:41:51+00 .. 2024-01-01 05:43:00+00}
(3 行)
```

外れ値がある場合、各インデックス ブロックに含まれる値の範囲が大幅に広くなります

### 外れ値を含むマルチミニマックス BRIN インデックス

BRIN インデックスのデフォルトの演算子クラスは minimax です。この演算子クラスを使用すると、各 BRIN インデックス エントリには、テーブル内の隣接するページの各範囲の最小値と最大値が 1 つずつ含まれます。相関関係が完全な場合はこれで問題ありませんが、外れ値がある場合、単一の minmax 範囲によってインデックスが多くの誤検出を返す可能性があります。

データベースが複数の最小値と最大値を保持するとしたらどうなるでしょうか。これにより、BRIN インデックスは外れ値に対してより耐性を持つようになります。PostgreSQL 14 では、まさにそれを実現する新しい演算子クラスのセット\*\_minmax_multi_ops が BRIN に追加されました。

外れ値のあるテーブルに BRIN インデックスを再作成してみましょう。ただし、今回は新しい multi-min-max 演算子クラスを使用します。

```sql
sample=# DROP INDEX t_outliers_happened_at_brin_minmax;
DROP INDEX
sample=# CREATE INDEX t_outliers_happened_at_brin_multi_minmax ON t_outliers
sample-# USING brin(happened_at timestamptz_minmax_multi_ops)
sample-# WITH (pages_per_range=10);
CREATE INDEX
```

マルチミニマックス インデックスは、単一のミニマックス インデックスよりも多くの情報を保持するため、サイズがわずかに大きくなります。

```sql
sample=# \di+ t_outliers_happened_at_brin_multi_minmax
                                                            リレーション一覧
 スキーマ |                   名前                   |    タイプ    |  所有者  |  テーブル  | 永続性 | アクセスメソッド | サイズ  | 説明
----------+------------------------------------------+--------------+----------+------------+--------+------------------+---------+------
 public   | t_outliers_happened_at_brin_multi_minmax | インデックス | postgres | t_outliers | 永続   | brin
| 2664 kB |
(1 行)
```

マルチミニマックス インデックスに見合った価値が得られるかを確認するには、外れ値のあるテーブルに対してクエリを実行します。

```sql
sample=# EXPLAIN (ANALYZE)
sample-# SELECT * FROM t_outliers WHERE happened_at BETWEEN '2023-01-12 13:45:00 UTC' AND '2023-01-12 13:46:00 UTC';
                                                                            QUERY PLAN

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on t_outliers  (cost=362.00..442.12 rows=1 width=1016) (actual time=9.795..9.869 rows=60 loops=1)
   Recheck Cond: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
   Rows Removed by Index Recheck: 60
   Heap Blocks: lossy=18
   ->  Bitmap Index Scan on t_outliers_happened_at_brin_multi_minmax  (cost=0.00..362.00 rows=72 width=0) (actual time=9.775..9.776 rows=720 loops=1)
         Index Cond: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
 Planning Time: 2.599 ms
 Execution Time: 9.922 ms
(8 行)
```

十分な速度が出ています。
Rows Removed by Index Recheck: 60 なので、効率的に検索出来ています。
マルチミニマックス BRIN インデックスがどのようにこの改善を実現したかをよりよく理解するには、最初のインデックス ブロックの内容を調べます。

```sql
sample=# SELECT blknum, value
sample-# FROM brin_page_items(get_raw_page('t_outliers_happened_at_brin_multi_minmax', 12), 't_outliers_happened_at_brin_multi_minmax')
sample-# ORDER BY 1 LIMIT 3;
 blknum |

                         value


--------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
   4500 | {{nranges: 2  nvalues: 14  maxvalues: 32 ranges: {"2023-01-01 08:45:01+00 ... 2023-01-01 08:45:02+00","2023-01-01 08:45:16+00 ... 2023-01-01 08:46:09+00"} values: {"2023-01-01 08:45:03+00","2023-01-01 08:45:04+00","2023-01-01 08:45:05+00","2023-01-01 08:45:06+00","2023-01-01 08:45:07+00","2023-01-01 08:45:08+00","2023-01-01 08:45:09+00","2023-01-01 08:45:10+00","2023-01-01 08:45:11+00","2023-01-01 08:45:12+00","2023-01-01 08:45:13+00","2023-01-01 08:45:14+00","2023-01-01 08:45:15+00","2024-01-01 08:46:10+00"}}}
   4510 | {{nranges: 2  nvalues: 14  maxvalues: 32 ranges: {"2023-01-01 08:46:11+00 ... 2023-01-01 08:46:12+00","2023-01-01 08:46:26+00 ... 2023-01-01 08:47:19+00"} values: {"2023-01-01 08:46:13+00","2023-01-01 08:46:14+00","2023-01-01 08:46:15+00","2023-01-01 08:46:16+00","2023-01-01 08:46:17+00","2023-01-01 08:46:18+00","2023-01-01 08:46:19+00","2023-01-01 08:46:20+00","2023-01-01 08:46:21+00","2023-01-01 08:46:22+00","2023-01-01 08:46:23+00","2023-01-01 08:46:24+00","2023-01-01 08:46:25+00","2024-01-01 08:47:20+00"}}}
   4520 | {{nranges: 2  nvalues: 14  maxvalues: 32 ranges: {"2023-01-01 08:47:21+00 ... 2023-01-01 08:47:22+00","2023-01-01 08:47:36+00 ... 2023-01-01 08:48:29+00"} values: {"2023-01-01 08:47:23+00","2023-01-01 08:47:24+00","2023-01-01 08:47:25+00","2023-01-01 08:47:26+00","2023-01-01 08:47:27+00","2023-01-01 08:47:28+00","2023-01-01 08:47:29+00","2023-01-01 08:47:30+00","2023-01-01 08:47:31+00","2023-01-01 08:47:32+00","2023-01-01 08:47:33+00","2023-01-01 08:47:34+00","2023-01-01 08:47:35+00","2024-01-01 08:48:30+00"}}}
(3 行)
```

マルチミニマックス BRIN インデックスの内容には、範囲と値の両方が含まれるようになりました。 値は基本的に単一の値の範囲です。

2024-01-01 08:46:10+00 は ranges に含まれません。
これは、マルチミニマックス BRIN インデックスが外れ値がインデックスに影響するのを防ぐ方法です。

### マルチミニマックス BRIN インデックスの仕組み

マルチミニマックス BRIN インデックスは隣接するページの範囲ごとの値の最大数を定義します。ミニマックス範囲は 2 つの値を占めます。ページ範囲に新しい値を追加する場合、アルゴリズムは次のように動作します。

- 隣接ページの範囲には複数の values_per_range 値が含まれていますか?  
  → いいえ -> 続行  
  → はい -> 値を最小最大範囲にグループ化して値の数を減らします

1 つの整数列を持つテーブルを使用した次のシミュレーションを考えてみましょう

```Sql
sample=# CREATE TABLE t_brin_minmax (n int);
CREATE TABLE
sample=#
sample=# CREATE INDEX t_brin_minmax_index ON t_brin_minmax
sample-# USING brin(n int4_minmax_multi_ops(values_per_range=8))
sample-# WITH (pages_per_range=2);
CREATE INDEX
```

単一の整数フィールドと、範囲ごとに 2 ページ、範囲ごとに最大 8 つの値を持つマルチミニマックス BRIN インデックスを持つテーブルを作成します。

### 結果の概要

前述のように、BRIN などの非可逆インデックスが B ツリーやハッシュ インデックスなどの他の種類のインデックスよりも優れている主な利点の 1 つは、そのサイズです。

```sql
sample=# CREATE INDEX t_happened_at_btree ON t(happened_at);
CREATE INDEX
sample=# \di+ t_happened_at_btree
                                                リレーション一覧
 スキーマ |        名前         |    タイプ    |  所有者  | テーブル | 永続性 | アクセスメソッド | サイズ | 説明
----------+---------------------+--------------+----------+----------+--------+------------------+--------+------
 public   | t_happened_at_btree | インデックス | postgres | t        | 永続   | btree            | 21 MB  |
(1 行)
```

```sql
sample=# EXPLAIN (ANALYZE)
sample-# SELECT * FROM t WHERE happened_at BETWEEN '2023-01-12 13:45:00 UTC' AND '2023-01-12 13:46:00 UTC';
                                                                         QUERY PLAN

-------------------------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using t_happened_at_btree on t  (cost=0.42..12.98 rows=68 width=1016) (actual time=0.036..0.060 rows=61 loops=1)
   Index Cond: ((happened_at >= '2023-01-12 13:45:00+00'::timestamp with time zone) AND (happened_at <= '2023-01-12 13:46:00+00'::timestamp with time zone))
 Planning Time: 3.540 ms
 Execution Time: 0.084 ms
(4 行)

```

B ツリー インデックスははるかに高速ですが、サイズもはるかに大きくなります。
