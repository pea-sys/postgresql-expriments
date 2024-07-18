# `pg_stat_statements`テーブルでクエリを監視

`pg_stat_statements`テーブルとはサーバで実行されたすべての SQL 文のプラン生成時と実行時の統計情報を記録する手段を提供します

postgresql.conf の shared_preload_libraries に pg_stat_statements を追加してモジュールをロード(`CREATE EXTENSION IF NOT EXISTS pg_stat_statements;`)しなければなりません。

`pg_stat_statements`テーブルには次の情報が格納されています。

| Column Name              | Data Type          | Description                                                                                                                      |
| ------------------------ | ------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| `userid`                 | `oid`              | SQL 文を実行したユーザの OID（参照先 `pg_authid`.`oid`）                                                                         |
| `dbid`                   | `oid`              | SQL 文が実行されたデータベースの OID（参照先 `pg_database`.`oid`）                                                               |
| `toplevel`               | `bool`             | 問い合わせが最上位レベルの SQL 文として実行された時は真 （`pg_stat_statements.track`が`top`に設定されている場合は常に真）        |
| `queryid`                | `bigint`           | 同一の正規化された問い合わせを識別するためのハッシュコード                                                                       |
| `query`                  | `text`             | 代表的な SQL 文の文字列                                                                                                          |
| `plans`                  | `bigint`           | SQL 文がプラン生成された回数 （`pg_stat_statements.track_planning`が有効な場合。無効であればゼロ）                               |
| `total_plan_time`        | `double precision` | SQL 文のプラン生成に費やした総時間（ミリ秒単位） （`pg_stat_statements.track_planning`が有効な場合。無効であればゼロ）           |
| `min_plan_time`          | `double precision` | SQL 文のプラン生成に費やした最小時間（ミリ秒単位） （`pg_stat_statements.track_planning`が有効な場合。無効であればゼロ）         |
| `max_plan_time`          | `double precision` | SQL 文のプラン生成に費やした最大時間（ミリ秒単位） （`pg_stat_statements.track_planning`が有効な場合。無効であればゼロ）         |
| `mean_plan_time`         | `double precision` | SQL 文のプラン生成に費やした平均時間（ミリ秒単位） （`pg_stat_statements.track_planning`が有効な場合。無効であればゼロ）         |
| `stddev_plan_time`       | `double precision` | SQL 文のプラン生成に費やした時間の母標準偏差（ミリ秒単位） （`pg_stat_statements.track_planning`が有効な場合。無効であればゼロ） |
| `calls`                  | `bigint`           | SQL 文が実行された回数                                                                                                           |
| `total_exec_time`        | `double precision` | SQL 文の実行に費やした総時間（ミリ秒単位）                                                                                       |
| `min_exec_time`          | `double precision` | SQL 文の実行に費やした最小時間（ミリ秒単位）                                                                                     |
| `max_exec_time`          | `double precision` | SQL 文の実行に費やした最大時間（ミリ秒単位）                                                                                     |
| `mean_exec_time`         | `double precision` | SQL 文の実行に費やした平均時間（ミリ秒単位）                                                                                     |
| `stddev_exec_time`       | `double precision` | SQL 文の実行に費やした時間の母標準偏差（ミリ秒単位）                                                                             |
| `rows`                   | `bigint`           | SQL 文によって取得された、あるいは影響を受けた行の総数                                                                           |
| `shared_blks_hit`        | `bigint`           | SQL 文によってヒットした共有ブロックキャッシュの総数                                                                             |
| `shared_blks_read`       | `bigint`           | SQL 文によって読み込まれた共有ブロックの総数                                                                                     |
| `shared_blks_dirtied`    | `bigint`           | SQL 文によってダーティ状態となった共有ブロックの総数                                                                             |
| `shared_blks_written`    | `bigint`           | SQL 文によって書き込まれた共有ブロックの総数                                                                                     |
| `local_blks_hit`         | `bigint`           | SQL 文によってヒットしたローカルブロックキャッシュの総数                                                                         |
| `local_blks_read`        | `bigint`           | SQL 文によって読み込まれたローカルブロックの総数                                                                                 |
| `local_blks_dirtied`     | `bigint`           | SQL 文によってダーティ状態となったローカルブロックの総数                                                                         |
| `local_blks_written`     | `bigint`           | SQL 文によって書き込まれたローカルブロックの総数                                                                                 |
| `temp_blks_read`         | `bigint`           | SQL 文によって読み込まれた一時ブロックの総数                                                                                     |
| `temp_blks_written`      | `bigint`           | SQL 文によって書き込まれた一時ブロックの総数                                                                                     |
| `blk_read_time`          | `double precision` | SQL 文がデータファイルブロックの読み取りに費やした総時間（ミリ秒単位） （track_io_timing が有効な場合。無効であればゼロ）        |
| `blk_write_time`         | `double precision` | SQL 文がデータファイルブロックの書き出しに費やした総時間（ミリ秒単位） （track_io_timing が有効な場合。無効であればゼロ）        |
| `temp_blk_read_time`     | `double precision` | SQL 文が一時ファイルブロックの読み取りに費やした総時間（ミリ秒単位） （track_io_timing が有効な場合。無効であればゼロ）          |
| `temp_blk_write_time`    | `double precision` | SQL 文が一時ファイルブロックの書き出しに費やした総時間（ミリ秒単位） （track_io_timing が有効な場合。無効であればゼロ）          |
| `wal_records`            | `bigint`           | SQL 文により生成された WAL レコードの総数                                                                                        |
| `wal_fpi`                | `bigint`           | SQL 文により生成された WAL フルページイメージの総数                                                                              |
| `wal_bytes`              | `numeric`          | SQL 文により生成されたバイト単位の WAL 総量                                                                                      |
| `jit_functions`          | `bigint`           | SQL 文が JIT コンパイルされた関数の総数                                                                                          |
| `jit_generation_time`    | `double precision` | SQL 文の JIT コードの生成に費やした総時間（ミリ秒単位）                                                                          |
| `jit_inlining_count`     | `bigint`           | 関数がインライン化された回数                                                                                                     |
| `jit_inlining_time`      | `double precision` | SQL 文が関数のインライン化に費やした総時間（ミリ秒単位）                                                                         |
| `jit_optimization_count` | `bigint`           | SQL 文が最適化された回数                                                                                                         |
| `jit_optimization_time`  | `double precision` | SQL 文の最適化に費やした総時間（ミリ秒単位）                                                                                     |
| `jit_emission_count`     | `bigint`           | コードが出力された回数                                                                                                           |
| `jit_emission_time`      | `double precision` | SQL 文のコードを出力するのに費やした総時間（ミリ秒単位）                                                                         |

下記のリポジトリを例にクエリを監視します

https://github.com/maybe-finance/maybe

```
データベース:maybe_development
ログインユーザー:postgres
```

### ステートメント統計情報の有効化

```sql
psql -U postgres maybe_development
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

### 監視ユーザーの作成

```sql
psql -U postgres postgres
postgres=# CREATE USER mon WITH LOGIN IN GROUP pg_monitor;
postgres=# \q
```

### 頻繁に実行されるクエリ

監視クエリがトップになりがちなので、監視クエリのユーザーをアプリユーザーと別に用意して、アプリユーザーでフィルタリングします。

```sql
watch 'psql -U mon -c "\\x on" -c "
SELECT
  substring(query, 0, 150) as query_snippet,
  calls,
  (total_exec_time / 1000 / 60) as total_min,
  mean_exec_time as avg_ms
FROM
  pg_stat_statements
WHERE
  userid IN (SELECT usesysid FROM pg_user WHERE usename = '\''postgres'\'')
ORDER BY
  calls DESC
LIMIT 5;
" maybe_development'
```

2 秒置きにクエリを再実行します

```
Every 2.0s: psql -U mon -c "\\x on" -c "                                                                    Ubuntu2404-WSL2: Wed Jul 17 21:53:42 2024

Expanded display is on.
-[ RECORD 1 ]-+--------------------------------------------------------------------------------------------------------------------------------------
----------------
query_snippet | SELECT "good_jobs"."id", "good_jobs"."queue_name", "good_jobs"."priority", "good_jobs"."serialized_params", "good_jobs"."scheduled_at
", "good_jobs"."
calls         | 135
total_min     | 5.797349999999998e-05
avg_ms        | 0.025765999999999994
-[ RECORD 2 ]-+--------------------------------------------------------------------------------------------------------------------------------------
----------------
query_snippet | UPDATE "good_job_processes" SET "updated_at" = $1 WHERE "good_job_processes"."id" = $2 /*application='Maybe'*/
calls         | 98
total_min     | 0.0005198790000000002
avg_ms        | 0.3182932653061224
-[ RECORD 3 ]-+--------------------------------------------------------------------------------------------------------------------------------------
----------------
query_snippet | COMMIT /*application='Maybe'*/
calls         | 98
total_min     | 2.4585e-06
avg_ms        | 0.0015052040816326533
-[ RECORD 4 ]-+--------------------------------------------------------------------------------------------------------------------------------------
----------------
query_snippet | BEGIN /*application='Maybe'*/
calls         | 98
total_min     | 2.7164999999999997e-06
avg_ms        | 0.001663163265306122
-[ RECORD 5 ]-+--------------------------------------------------------------------------------------------------------------------------------------
----------------
query_snippet | SELECT "good_job_processes".* FROM "good_job_processes" WHERE "good_job_processes"."id" = $1 LIMIT $2 /*application='Maybe'*/
calls         | 98
total_min     | 0.00010258050000000002
avg_ms        | 0.06280438775510205
```

### 遅いクエリを監視

```sql
watch 'psql -U mon -c "\\x on" -c "
SELECT
  substring(query, 0, 150) as query_snippet,
  calls,
  mean_exec_time as avg_ms
FROM
  pg_stat_statements
WHERE
  mean_exec_time >1 AND userid IN (SELECT usesysid FROM pg_user WHERE usename = '\''postgres'\'')
ORDER BY
  mean_exec_time DESC
LIMIT 5;
" maybe_development'
```

2 秒置きにクエリを再実行します

```
Every 2.0s: psql -U mon -c "\\x on" -c "                          Ubuntu2404-WSL2: Wed Jul 17 21:56:28 2024

Expanded display is on.
-[ RECORD 1 ]-+---------------------------------------------------------------------------
query_snippet | select * from pg_stat_statements
calls         | 1
avg_ms        | 2.556
-[ RECORD 2 ]-+---------------------------------------------------------------------------
query_snippet | select * from pg_stat_statements , (select usename, usesysid from pg_user)
calls         | 1
avg_ms        | 1.2491100000000002
-[ RECORD 3 ]-+---------------------------------------------------------------------------
query_snippet | select * from pg_stat_statements , pg_user
calls         | 1
avg_ms        | 1.02447
```

### 多くの行数を返すクエリを監視

```
watch 'psql -U mon -c "\\x on" -c "
SELECT
    query,
    rows
FROM
    pg_stat_statements
ORDER BY
    rows DESC
LIMIT
    10;
" maybe_development'
```

```
Every 2.0s: psql -U mon -c "\\x on" -c "                                               Ubuntu2404-WSL2: Wed Jul 17 22:36:13 2024

Expanded display is on.
-[ RECORD 1 ]-------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
query | SELECT "account_balances".* FROM "account_balances" WHERE "account_balances"."account_id" = $1 AND "account_balances"."d
ate" <= $2 AND "account_balances"."currency" = $3 /*action='summary',application='Maybe',controller='accounts'*/
rows  | 27395
-[ RECORD 2 ]-------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
query | SELECT "account_balances".* FROM "account_balances" WHERE "account_balances"."account_id" = $1 AND "account_balances"."d
ate" BETWEEN $2 AND $3 AND "account_balances"."currency" = $4 /*action='new',application='Maybe',controller='accounts'*/
rows  | 12770
```

### ステートメント統計情報の初期化

測定開始と終了時に初期化しておきます。

```sql
select pg_stat_statements_reset();
```

以上

### 参考

https://neon.tech/docs/extensions/pg_stat_statements
