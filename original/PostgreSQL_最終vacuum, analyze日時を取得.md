# PostgreSQL 最終`vacuum`, `analyze` 日時を取得

クエリが継続的に適切に実行されるためには、`vacuum` や `analyze` の存在が欠かせません。  
そのため、最終`vacuum`、`analyze` 日時を定期的に監視する必要があります。

そのための便利なクエリの使い方を残しておきます。

テーブルセットアップ

```
postgres@masami-L ~ > pgbench -i
dropping old tables...
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.09 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.57 s (drop tables 0.02 s, create tables 0.02 s, client-side generate 0.17 s, vacuum 0.07 s, primary keys 0.29 s).
postgres@masami-L ~> pgbench -c 10 -T 100
pgbench (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 10
number of threads: 1
duration: 100 s
number of transactions actually processed: 25671
latency average = 38.961 ms
initial connection time = 28.953 ms
tps = 256.668551 (without initial connection time)
```

最終 vacuum. analuze 日時を取得

```sql
postgres=# SELECT relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_all_tables
WHERE schemaname = 'public'
ORDER BY relname;
     relname      | n_live_tup | n_dead_tup |          last_vacuum          |        last_autovacuum        |         last_analyze          |       last_autoanalyze
------------------+------------+------------+-------------------------------+-------------------------------+-------------------------------+-------------------------------
 pgbench_accounts |     100000 |       3866 | 2024-02-18 11:19:19.939566+09 | 2024-02-18 11:19:30.51323+09  | 2024-02-18 11:19:19.9777+09   | 2024-02-18 11:21:30.638838+09
 pgbench_branches |          1 |          0 | 2024-02-18 11:19:35.479241+09 | 2024-02-18 11:21:30.654551+09 | 2024-02-18 11:19:19.923432+09 | 2024-02-18 11:21:30.654742+09
 pgbench_history  |      25671 |          0 | 2024-02-18 11:19:19.982612+09 | 2024-02-18 11:21:30.688762+09 | 2024-02-18 11:19:19.982845+09 | 2024-02-18 11:21:30.72651+09
 pgbench_tellers  |         10 |          0 | 2024-02-18 11:19:35.479723+09 | 2024-02-18 11:21:30.669118+09 | 2024-02-18 11:19:19.927675+09 | 2024-02-18 11:21:30.669353+09
(4 rows)
```
