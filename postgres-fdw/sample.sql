-- https://tech-lab.sios.jp/archives/8641を見よう見まねで実施

initdb --no-locale -E UTF-8 local
データベースシステム内のファイルの所有者はユーザー"user"となります。
このユーザーをサーバープロセスの所有者とする必要があります。

データベースクラスタはロケール"C"で初期化されます。
デフォルトのテキスト検索構成は english に設定されます。

データベージのチェックサムは無効です。

ディレクトリlocalを作成しています ... ok
サブディレクトリを作成しています ... ok
動的共有メモリの実装を選択しています ... windows
デフォルトのmax_connectionsを選択しています ... 100
デフォルトのshared_buffersを選択しています ... 128MB
デフォルトの時間帯を選択しています ... Asia/Tokyo
設定ファイルを作成しています ... ok
ブートストラップスクリプトを実行しています ... ok
ブートストラップ後の初期化を実行しています ... ok
データをディスクに同期しています... ok

initdb: 警告: ローカル接続に対して"trust"認証を有効にします
pg_hba.confを編集する、もしくは、次回initdbを実行する時に -A オプション、
あるいは --auth-local および --auth-host オプションを使用することで変更する
ことがきます。

成功しました。以下のようにしてデータベースサーバーを起動することができます:

    pg_ctl -D local -l ログファイル start

C:\Users\user>initdb --no-locale -E UTF-8 remote
データベースシステム内のファイルの所有者はユーザー"user"となります。
このユーザーをサーバープロセスの所有者とする必要があります。

データベースクラスタはロケール"C"で初期化されます。
デフォルトのテキスト検索構成は english に設定されます。

データベージのチェックサムは無効です。

ディレクトリremoteを作成しています ... ok
サブディレクトリを作成しています ... ok
動的共有メモリの実装を選択しています ... windows
デフォルトのmax_connectionsを選択しています ... 100
デフォルトのshared_buffersを選択しています ... 128MB
デフォルトの時間帯を選択しています ... Asia/Tokyo
設定ファイルを作成しています ... ok
ブートストラップスクリプトを実行しています ... ok
ブートストラップ後の初期化を実行しています ... ok
データをディスクに同期しています... ok

initdb: 警告: ローカル接続に対して"trust"認証を有効にします
pg_hba.confを編集する、もしくは、次回initdbを実行する時に -A オプション、
あるいは --auth-local および --auth-host オプションを使用することで変更する
ことがきます。

成功しました。以下のようにしてデータベースサーバーを起動することができます:

    pg_ctl -D remote -l ログファイル start


C:\Users\user>pg_ctl -D local/ -l local.logfile start
サーバーの起動完了を待っています....完了
サーバー起動完了

C:\Users\user>pg_ctl -D remote/ -l remote.logfile start
サーバーの起動完了を待っています....完了
サーバー起動完了

C:\Users\user>createdb -h 127.0.0.1 -p 5488

C:\Users\user>createdb -h 127.0.0.1 -p 5499

C:\Users\user>pgbench -i -s 20 -h 127.0.0.1 -p 5499
dropping old tables...
NOTICE:  table "pgbench_accounts" does not exist, skipping
NOTICE:  table "pgbench_branches" does not exist, skipping
NOTICE:  table "pgbench_history" does not exist, skipping
NOTICE:  table "pgbench_tellers" does not exist, skipping
creating tables...
generating data (client-side)...
2000000 of 2000000 tuples (100%) done (elapsed 8.37 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 15.28 s (drop tables 0.01 s, create tables 0.04 s, client-side generate 10.77 s, vacuum 1.74 s, primary keys 2.72 s).

C:\Users\user>psql -h 127.0.0.1 -p 5488
psql (14.2)
"help"でヘルプを表示します。

user=# CREATE EXTENSION postgres_fdw;
CREATE EXTENSION
user=# CREATE SERVER remote FOREIGN DATA WRAPPER postgres_fdw
user-#   OPTIONS (host '127.0.0.1', dbname 'user', port '5499');
CREATE SERVER
user=#
user=# CREATE USER MAPPING FOR user SERVER remote OPTIONS (user 'user');
CREATE USER MAPPING
user=# IMPORT FOREIGN SCHEMA public FROM SERVER remote INTO public;
IMPORT FOREIGN SCHEMA
user=# \d
                  リレーション一覧
 スキーマ |       名前       |    タイプ    | 所有者
----------+------------------+--------------+--------
 public   | pgbench_accounts | 外部テーブル | user
 public   | pgbench_branches | 外部テーブル | user
 public   | pgbench_history  | 外部テーブル | user
 public   | pgbench_tellers  | 外部テーブル | user
(4 行)

C:\Users\user>pg_ctl -D local/ -l local.logfile start
サーバーの起動完了を待っています....完了
サーバー起動完了

C:\Users\user>pg_ctl -D remote/ -l remote.logfile start
サーバーの起動完了を待っています....完了
サーバー起動完了

C:\Users\user>pgbench -c 20 -T 10 -p 5499 -h 127.0.0.1
pgbench (14.2)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 20
query mode: simple
number of clients: 20
number of threads: 1
duration: 10 s
number of transactions actually processed: 14386
latency average = 12.855 ms
initial connection time = 778.139 ms
tps = 1555.815615 (without initial connection time)

C:\Users\user>pgbench -c 20 -T 10 -p 5488 -h 127.0.0.1
pgbench (14.2)
starting vacuum...WARNING:  skipping "pgbench_branches" --- cannot vacuum non-tables or special system tables
WARNING:  skipping "pgbench_tellers" --- cannot vacuum non-tables or special system tables
end.
pgbench: error: client 9 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-1201)) WHERE ((bid = 10))
pgbench: error: client 6 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-3534)) WHERE ((bid = 6))
pgbench: error: client 19 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-3224)) WHERE ((bid = 15))
pgbench: error: client 2 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-2996)) WHERE ((bid = 8))
pgbench: error: client 8 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + 2495) WHERE ((bid = 7))
pgbench: error: client 10 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-4127)) WHERE ((bid = 5))
pgbench: error: client 1 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + 48) WHERE ((bid = 8))
pgbench: error: client 15 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-4660)) WHERE ((bid = 8))
pgbench: error: client 18 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-1241)) WHERE ((bid = 3))
pgbench: error: client 5 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + 960) WHERE ((bid = 7))
pgbench: error: client 12 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-3579)) WHERE ((bid = 16))
pgbench: error: client 0 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-4444)) WHERE ((bid = 12))
pgbench: error: client 3 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-2392)) WHERE ((bid = 17))
pgbench: error: client 11 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + 338) WHERE ((bid = 16))
pgbench: error: client 4 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-3453)) WHERE ((bid = 12))
pgbench: error: client 16 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-1066)) WHERE ((bid = 19))
pgbench: error: client 14 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-3114)) WHERE ((bid = 2))
pgbench: error: client 7 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + (-3456)) WHERE ((bid = 17))
pgbench: error: client 17 script 0 aborted in command 8 query 0: ERROR:  could not serialize access due to concurrent update
CONTEXT:  remote SQL command: UPDATE public.pgbench_branches SET bbalance = (bbalance + 759) WHERE ((bid = 15))
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 20
query mode: simple
number of clients: 20
number of threads: 1
duration: 10 s
number of transactions actually processed: 2924
latency average = 63.295 ms
initial connection time = 754.361 ms
tps = 315.979667 (without initial connection time)
pgbench: fatal: Run was aborted; the above results are incomplete.