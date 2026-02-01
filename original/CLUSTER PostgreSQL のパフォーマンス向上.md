https://www.cybertec-postgresql.com/en/cluster-improving-postgresql-performance/

# CLUSTER: PostgreSQL のパフォーマンス向上

## PostgreSQL: ソートするかしないか

ディスク上のレイアウトの重要性を示すために、簡単なテスト セットを作成しました。

```sql
sample=# CREATE TABLE t_test AS SELECT *
sample-#                FROM generate_series(1, 10000000);
SELECT 10000000
sample=# CREATE TABLE t_random AS SELECT *
sample-#                FROM t_test
sample-#                ORDER BY random();
SELECT 10000000
```

データサイズは同一

```
sample-# \d+
                                   リレーション一覧
 スキーマ |   名前   |  タイプ  |  所有者  | 永続性 | アクセスメソッド | サイズ | 説明
----------+----------+----------+----------+--------+------------------+--------+------
 public   | t_random | テーブル | postgres | 永続   | heap             | 346 MB |
 public   | t_test   | テーブル | postgres | 永続   | heap             | 346 MB |
(2 行)
```

## PostgreSQLでインデックスを作成する

```sql
sample=#  CREATE INDEX idx_test ON t_test (generate_series);
CREATE INDEX
時間: 7585.277 ミリ秒(00:07.585)
sample=# CREATE INDEX idx_random ON t_random (generate_series);
CREATE INDEX
時間: 7882.507 ミリ秒(00:07.883)
```

オプティマイザー統計を作成

```sql
VACUUM
時間: 1437.425 ミリ秒(00:01.437)
```

## データベースのブロックの読み取り

簡単なテストを実行

```sql
sample=# explain (analyze, buffers) SELECT *
sample-#        FROM    t_test
sample-#        WHERE   generate_series BETWEEN 1000 AND 50000;
                                                             QUERY PLAN
------------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using idx_test on t_test  (cost=0.43..1140.93 rows=49545 width=4) (actual time=0.054..9.023 rows=49001.00 loops=1)
   Index Cond: ((generate_series >= 1000) AND (generate_series <= 50000))
   Heap Fetches: 0
   Index Searches: 1
   Buffers: shared hit=3 read=135
 Planning:
   Buffers: shared hit=38 read=3
 Planning Time: 2.936 ms
 Execution Time: 10.897 ms
(9 行)


時間: 20.931 ミリ秒
```

必要な8kブロックの数が135個

```sql
sample=# explain (analyze, buffers) SELECT *
sample-#        FROM    t_random
sample-#        WHERE   generate_series BETWEEN 1000 AND 50000;
                                                               QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using idx_random on t_random  (cost=0.43..1080.41 rows=46904 width=4) (actual time=0.061..9.646 rows=49001.00 loops=1)
   Index Cond: ((generate_series >= 1000) AND (generate_series <= 50000))
   Heap Fetches: 0
   Index Searches: 1
   Buffers: shared hit=18875 read=135
 Planning:
   Buffers: shared hit=19 read=3
 Planning Time: 2.910 ms
 Execution Time: 11.277 ms
(9 行)


時間: 14.765 ミリ秒
```

クエリは少し長くなりました。必要なブロック数は18875ブロック。
クエリは実際にはそれほど遅くないと主張する人もいるかもしれません。確かにその通りです。しかし、私の例ではすべてのデータがメモリから取得されています。ここで、何らかの理由でキャッシュヒットが得られず、データをディスクから読み込まなければならないと仮定してみましょう。状況は劇的に変化します。ディスクから1ブロックを読み取るのに0.1ミリ秒かかると仮定してみましょう。

135 _ 0.1 + 10.8 = 24.3 ミリ秒
vs.
18875 _ 0.1 + 11.3 = 1898.8 ミリ秒

これは大きな違いです。一見そうは思えないかもしれませんが、ブロック数は確かに影響を及ぼします。キャッシュヒット率が低いほど、問題は大きくなります。
この例には、考慮すべき点がもう1つあります。数行だけを読み取りたい場合、ディスク上のレイアウトはそれほど大きな違いを生みません。しかし、データのサブセットに数千行が含まれる場合、ディスク上の順序付けはパフォーマンスに影響を与えます。

## CLUSTER: PostgreSQLが救世主となる

このコマンドを使用すると、インデックスに従ってデータを整理できます。構文は次のとおりです。

```sql
sample-# \h CLUSTER
コマンド:    CLUSTER
説明: インデックスに従ってテーブルをクラスタ化します
書式:
CLUSTER [ ( オプション [, ...] ) ] [ テーブル名 [ USING インデックス名 ] ]

オプションには以下のうちのいずれかを指定します:

    VERBOSE [ 真偽値 ]

URL: https://www.postgresql.org/docs/18/sql-cluster.html
```

```sql
sample=# CLUSTER t_random USING idx_random;
CLUSTER
時間: 43293.005 ミリ秒(00:43.293)
```

以前と同じクエリをもう一度実行します。

```sql
sample=# explain (analyze, buffers)
sample-#        SELECT *        FROM t_random
sample-#        WHERE   generate_series BETWEEN 1000 AND 50000;
                                                           QUERY PLAN
--------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on t_random  (cost=623.10..32496.58 rows=46904 width=4) (actual time=4.930..17.842 rows=49001.00 loops=1)
   Recheck Cond: ((generate_series >= 1000) AND (generate_series <= 50000))
   Heap Blocks: exact=218
   Buffers: shared hit=2 read=353
   ->  Bitmap Index Scan on idx_random  (cost=0.00..611.38 rows=46904 width=0) (actual time=4.353..4.353 rows=49001.00 loops=1)
         Index Cond: ((generate_series >= 1000) AND (generate_series <= 50000))
         Index Searches: 1
         Buffers: shared hit=2 read=135
 Planning:
   Buffers: shared hit=21 read=5
 Planning Time: 3.083 ms
 Execution Time: 22.221 ms
(12 行)
```

PostgreSQLは実行計画を変更しました。これは統計情報が誤っているために発生します。そのため、ANALYZEを実行してオプティマイザが最新の情報を取得していることを確認することが重要です。

```sql
sample=# ANALYZE;
ANALYZE
時間: 5716.184 ミリ秒(00:05.716)
```

新しいオプティマイザ統計が配置されると、実行プランは再び期待どおりになります。

```sql
sample=#  explain (analyze, buffers) SELECT *
sample-#        FROM    t_random
sample-#        WHERE   generate_series BETWEEN 1000 AND 50000;
                                                               QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using idx_random on t_random  (cost=0.43..1357.99 rows=49443 width=4) (actual time=0.039..12.691 rows=49001.00 loops=1)
   Index Cond: ((generate_series >= 1000) AND (generate_series <= 50000))
   Heap Fetches: 49001
   Index Searches: 1
   Buffers: shared hit=355
 Planning:
   Buffers: shared hit=28
 Planning Time: 2.273 ms
 Execution Time: 14.941 ms
(9 行)


時間: 19.215 ミリ秒
```
