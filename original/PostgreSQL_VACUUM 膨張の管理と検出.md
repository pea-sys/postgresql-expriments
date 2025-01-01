# PostgreSQL の VACUUM が OS にスペースを返さない理由

データベース作成

```shell
createdb -U postgres sample
psql -U postgres -d sample
```

バージョン確認

```
sample=# select version();
                          version
------------------------------------------------------------
 PostgreSQL 16.2, compiled by Visual C++ build 1937, 64-bit
(1 行)
```

テストデータ作成

```Sql
sample=# CREATE TABLE t_vacuum (
sample(#           id    int,
sample(#           x    char(1500) DEFAULT 'abc'
sample(# );
CREATE TABLE
sample=# INSERT INTO t_vacuum
sample-#      SELECT id FROM generate_series(1, 30) AS id;
INSERT 0 30
sample=# SELECT ctid, id FROM t_vacuum;
 ctid  | id
-------+----
 (0,1) |  1
 (0,2) |  2
 (0,3) |  3
 (0,4) |  4
 (0,5) |  5
 (1,1) |  6
 (1,2) |  7
 (1,3) |  8
 (1,4) |  9
 (1,5) | 10
 (2,1) | 11
 (2,2) | 12
 (2,3) | 13
 (2,4) | 14
 (2,5) | 15
 (3,1) | 16
 (3,2) | 17
 (3,3) | 18
 (3,4) | 19
 (3,5) | 20
 (4,1) | 21
 (4,2) | 22
 (4,3) | 23
 (4,4) | 24
 (4,5) | 25
 (5,1) | 26
 (5,2) | 27
 (5,3) | 28
 (5,4) | 29
 (5,5) | 30
(30 行)
```

PostgreSQL の 8k ブロックには 5 行しか収まりません。どの行がどこにあるかを確認するには、「ctid」という非表示の列を利用できます。この列には、ブロックの番号とブロック内の行が含まれています (ctid = '(2, 4)' は 3 番目のブロックの 4 番目の行を意味します)。行を削除して VACUUM を実行するとどうなるでしょうか。その前に、テーブル内で何が起こっているかを実際に確認するための拡張機能をいくつか有効にすることができます。

```sql
sample=# CREATE EXTENSION pg_freespacemap;
CREATE EXTENSION
sample=# SELECT * FROM pg_freespace('t_vacuum');
 blkno | avail
-------+-------
     0 |   448
     1 |   448
     2 |   448
     3 |   448
     4 |   448
     5 |     0
(6 行)
```

この拡張機能により、8k ブロックのそれぞれにどのくらいのスペースがあるかがわかります。この場合、ブロックあたり 448 バイトです。その理由は、行が 1 つのブロックに収まる必要があるためです (この場合)。

何が起こったのかがわかったので、いくつかのデータを削除して何が起こっているのか確認してみましょう。

```sql
sample=# DELETE FROM t_vacuum
sample-#            WHERE  id = 7 OR id = 8
sample-#            RETURNING ctid;
 ctid
-------
 (1,2)
 (1,3)
(2 行)
```

ここで確認できるのは、データ ファイル内のギャップです。

```sql
sample-#         FROM   t_vacuum
sample-#         WHERE  id BETWEEN 5 AND 10;
 ctid  | id
-------+----
 (0,5) |  5
 (1,1) |  6
 (1,4) |  9
 (1,5) | 10
(4 行)
```

行 (1, 2) と (1, 3) は消えています (= デッドとしてマークされています)。理解する必要があるのは、データは基本的にディスク上でデッドになっているということです。空き領域マップの内容を見ると、変更されていないことがわかります。

```sql
sample=# SELECT * FROM pg_freespace('t_vacuum');
 blkno | avail
-------+-------
     0 |   448
     1 |   448
     2 |   448
     3 |   448
     4 |   448
     5 |     0
(6 行)
```

これは重要なポイントです: データが削除されてもスペースは解放されません - スペースは VACUUM によって回収されます:

```sql
sample=# VACUUM t_vacuum;
VACUUM
```

VACUUM が実行されると (長時間実行されているトランザクションが作業をブロックしていないと仮定)、空き領域マップ (= FSM) はディスク上の新しい現実を反映します。

```sql
sample=# SELECT * FROM pg_freespace('t_vacuum');
 blkno | avail
-------+-------
     0 |   448
     1 |  3520
     2 |   448
     3 |   448
     4 |   448
     5 |   448
(6 行)
```

まだ 5 つのブロックがあることに注意してください。違いは、2 番目のブロックに空き領域がかなり多くあることです。通常の VACUUM では、ブロック間でデータを移動しません。これは単にその方法だからです。したがって、スペースはオペレーティング システム (ファイル システム) に返されません。ただし、ほとんどの場合、後で使用したいので、これはあまり問題ではありません。

```sql
sample=# INSERT INTO t_vacuum
sample-#            VALUES (999, 'abcdefg')
sample-#            RETURNING ctid;
 ctid
-------
 (1,2)
(1 行)
sample=# VACUUM ;
VACUUM
sample=# SELECT * FROM pg_freespace('t_vacuum');
 blkno | avail
-------+-------
     0 |   448
     1 |  1984
     2 |   448
     3 |   448
     4 |   448
     5 |   448
(6 行)
```

ご覧のとおり、次の書き込みでギャップが埋められ、スペースが再割り当てされます。これは、VACUUM FULL 後にファイルシステム (オペレーティング システム) にスペースを返すことは一時的なものであることを意味するため重要です。次の書き込み操作では、とにかくすぐにファイルシステムのスペースが要求されます。実際には、VACUUM FULL は人々が考えるほど重要ではありません。まったく逆で、厳しいテーブル ロックが必要になるため、問題が発生する可能性があります。VACUUM FULL が無意味だと言っているのではありません。ここで言っているのは、VACUUM FULL があまりにも頻繁に使用されているということです。

# pg_squeeze: テーブルをより効率的に縮小する

VACUUM FULL の問題は、テーブル ロックが必要であることです。多くの場合、これは本質的に「ダウンタイム」を意味します。テーブルにデータを書き込むことができない場合、基本的にはアプリケーションが使用できなくなったことを意味します。

これに代わるものとして、pg_squeeze があります。これは、パッケージ マネージャー経由で追加して、過剰なロックなしでテーブルを再編成できるオープン ソース ツールです。これにより、プロセス中に書き込みをブロックせずにテーブルを再編成できます。

仕組みとしては、テーブル内のデータの初期（小さな）コピー（肥大化したデータを除く）を取得し、その初期コピー中に発生した変更を適用します。プロセスの最後に、データ ファイルはシステム カタログにスワップ アウトされ、ロックは最小限（数ミリ秒のみ）になります。

# 組織的に肥大化を検出する

主な問題は、肥大化と戦う前に、実際にどのテーブルが肥大化していて、どのテーブルが肥大化していないかを調べることが良い考えだということです。単一のテーブルに対してこれを行うには、 PostgreSQL contrib パッケージの一部である pgstattuple 拡張機能を使用します。その仕組みは次のとおりです。

```sql
sample=# CREATE EXTENSION pgstattuple;
CREATE EXTENSION
```

再度サンプルデータを作成します。

```sql
sample=# CREATE TABLE t_bloat AS
sample-#            SELECT     id
sample-#            FROM        generate_series(1, 1000000) AS id;
SELECT 1000000
```

一部のデータが削除されると何が起こるかを見てみましょう。

```sql
sample=# DELETE FROM t_bloat WHERE id < 50000;
DELETE 49999
sample=# VACUUM t_bloat;
VACUUM
```

pgstattuple を呼び出すと、テーブルを検査してデータ ファイルの構成を確認できます。pgstattuple の出力はかなり広範なテーブルなので、\x を使用して出力をよりわかりやすくすることができます。

```sql
sample=# \x
拡張表示は on です。
sample=# SELECT * FROM pgstattuple('t_bloat');
-[ RECORD 1 ]------+---------
table_len          | 36249600
tuple_count        | 950001
tuple_len          | 26600028
tuple_percent      | 73.38
dead_tuple_count   | 0
dead_tuple_len     | 0
dead_tuple_percent | 0
free_space         | 1924568
free_percent       | 5.31
```

データ ファイルのサイズ (table_len) とテーブル内の行数 (tuple_count) を確認できます。また、デッド スペースの量 (dead_tuple_len) とテーブル内の空きスペースの量も確認できます。「有効 + デッド + 空き = テーブル サイズ」であることを覚えておいてください。重要な点は、これらの値が有用な比率である必要があることです。アプリケーションのタイプに応じて、これは当然変化する可能性があるため、「何が良いか」と「何が悪いか」の固定しきい値に固執することは役に立ちません。

ただし、1 つだけ留意する必要があります。pgstattuple 関数はテーブル全体をスキャンします。つまり、テーブルが 25 TB の場合、その数値を取得するためだけに 25 TB を読み取ることになります。実際には、これは大きな問題になる可能性があります。この問題を解決するために、PostgreSQL はテーブル全体を読み取るのではなく、サンプルを取得する pgstattuple_approx 関数を提供しています。その仕組みは次のとおりです。

```sql
sample=# SELECT * FROM pgstattuple_approx('t_bloat');
-[ RECORD 1 ]--------+------------------
table_len            | 36249600
scanned_percent      | 0
approx_tuple_count   | 938343
approx_tuple_len     | 34442720
approx_tuple_percent | 95.01544844632768
dead_tuple_count     | 0
dead_tuple_len       | 0
dead_tuple_percent   | 0
approx_free_space    | 1806880
approx_free_percent  | 4.984551553672317
```

# pgstattuple を「大規模に」実行する

これまで、単一のテーブルに対して pgstattuple を実行する方法を学びました。しかし、データベース内のすべてのテーブルに対してこれを実行するにはどうすればよいですか?

役に立つかもしれないクエリは次のとおりです。

```sql
sample=# SELECT a.oid::regclass AS table_name,
sample-#        b.*
sample-# FROM  (SELECT  oid
sample(#        FROM    pg_class
sample(#        WHERE   oid > 16384
sample(#                AND relkind = 'r') AS a,
sample-#       LATERAL (SELECT *
sample(#                 FROM pgstattuple_approx(a.oid) AS c
sample(#                 ) AS b
sample-# ORDER BY 2 DESC;
-[ RECORD 1 ]--------+------------------
table_name           | t_bloat
table_len            | 36249600
scanned_percent      | 0
approx_tuple_count   | 938343
approx_tuple_len     | 34442720
approx_tuple_percent | 95.01544844632768
dead_tuple_count     | 0
dead_tuple_len       | 0
dead_tuple_percent   | 0
approx_free_space    | 1806880
approx_free_percent  | 4.984551553672317
-[ RECORD 2 ]--------+------------------
table_name           | t_vacuum
table_len            | 49152
scanned_percent      | 0
approx_tuple_count   | 29
approx_tuple_len     | 44928
approx_tuple_percent | 91.40625
dead_tuple_count     | 0
dead_tuple_len       | 0
dead_tuple_percent   | 0
approx_free_space    | 4224
approx_free_percent  | 8.59375
```

クエリはデータベース内のすべての非システム テーブルを返し、それらを 1 つずつ検査します。リストは順序付けされています (最大のテーブルが最初)。

# 膨張の制御がなぜ役立つのか

VACUUM に関連して、見落とされがちな重要な側面があります。多くの人は、テーブルを縮小することはどんな状況でも有益だと考えています。しかし、これは必ずしも真実ではありません。テーブルに多くの UPDATE ステートメントが実行される場合は、FILLFACTOR と呼ばれるものを使用すると効果的です。これは、8k ブロックを完全に埋めるのではなく、UPDATE が行のコピーを同じブロックに入れるためのスペースを残すという考え方です。この戦略を使用すると、一部の I/O を回避して効率を上げることができます。

最初に作成したテーブルに戻って、これがなぜ重要なのかを確認しましょう。

```sql
sample=# TRUNCATE t_vacuum ;
TRUNCATE TABLE
sample=# INSERT INTO t_vacuum
sample-#            SELECT id FROM generate_series(1, 10) AS id;
INSERT 0 10
```

リストはテーブルを空にし、10 個の新しい大きな行を追加します。

```sql
sample=# \x
拡張表示は off です。
sample=# SELECT ctid, id FROM t_vacuum;
 ctid  | id
-------+----
 (0,1) |  1
 (0,2) |  2
 (0,3) |  3
 (0,4) |  4
 (0,5) |  5
 (1,1) |  6
 (1,2) |  7
 (1,3) |  8
 (1,4) |  9
 (1,5) | 10
(10 行)
```

2 つのブロックが密集していることがわかります。つまり、UPDATE では、作成するコピーを同じブロック内にそのまま保持することはできません。したがって、更新された行を含む最初のブロックを操作し、新しいバージョンを含む新しいブロックを書き込む必要があります。

```sql
sample=# UPDATE t_vacuum SET id = 100 WHERE id = 1;
UPDATE 1
sample=# SELECT ctid, id FROM t_vacuum;
 ctid  | id
-------+-----
 (0,2) |   2
 (0,3) |   3
 (0,4) |   4
 (0,5) |   5
 (1,1) |   6
 (1,2) |   7
 (1,3) |   8
 (1,4) |   9
 (1,5) |  10
 (2,1) | 100
(10 行)
```

つまり、1 行を更新するためだけに 2 つのブロックに触れる必要がありました。次の例に示すように、ブロック内にまだいくらかのスペースが残っている場合は状況が変わります。

```sql
sample=# UPDATE t_vacuum SET id = 999 WHERE id = 100;
UPDATE 1
sample=# SELECT ctid, id FROM t_vacuum;
 ctid  | id
-------+-----
 (0,2) |   2
 (0,3) |   3
 (0,4) |   4
 (0,5) |   5
 (1,1) |   6
 (1,2) |   7
 (1,3) |   8
 (1,4) |   9
 (1,5) |  10
 (2,2) | 999
(10 行)
```

ブロック番号 3 のみが変更されていることがわかります。ctid '(2,1)' はなくなり、コピーは同じブロックである '(2, 2)' に配置されています。必要なディスク I/O は半分だけです。巧妙な FILLFACTOR (通常は 60 から 80 の間) を設定することで、このタイプの UPDATE (同じブロック内) の可能性を高めることができます。

```sql
sample=# ALTER TABLE t_vacuum SET (FILLFACTOR=60);
ALTER TABLE
```
