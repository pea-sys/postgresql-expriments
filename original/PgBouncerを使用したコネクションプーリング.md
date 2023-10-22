# PgBouncerを使用したコネクションプーリング

PgBouncerはPostgreSQL用の軽量接続プーラーです。  
https://www.pgbouncer.org/  
今回はPgBouncerの効果を確認する。

* DB作成
```
C:\Users\masami>psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF-8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';"
ユーザー postgres のパスワード:
CREATE DATABASE

C:\Users\masami>psql -U postgres -d sample
ユーザー postgres のパスワード:
psql (16.0)
"help"でヘルプを表示します。
```
* PgBouncerのユーザー作成
```
sample=# create user pgbouncer_user WITH PASSWORD '12345' SUPERUSER; CREATE ROLE
CREATE ROLE
sample=# select rolname, rolpassword from pg_authid where rolname='pgbouncer_user';
    rolname     |                                                              rolpassword

----------------+---------------------------------------------------------------------------------------------------------------------------------------
 pgbouncer_user | SCRAM-SHA-256$4096:2G4gdV5yagn0wMsnoU6xuA==$2It/oGsIjJko+1G8rPuuVj8EC2ynftnG0bly62sA7wk=:o7n/s7gCBMa/sD1igS2GHkHVIVnog3aghPvpdyvKDYY=
(1 行)
```
* PgBouncerの設定  

"C:\Program Files\PgBouncer\share\pgbouncer.ini"を編集
```
[databases]

;; foodb over Unix socket
;; postgres = host=127.0.0.1 port=5432
sample = host=localhost port=5432 user=pgbouncer_user dbname=sample password=12345

admin_users = pgbouncer_user
```
"C:\Program Files\PgBouncer\etc\userlist.txt"を編集
```
"pgbouncer_user" "SCRAM-SHA-256$4096:2G4gdV5yagn0wMsnoU6xuA==$2It/oGsIjJko+1G8rPuuVj8EC2ynftnG0bly62sA7wk=:o7n/s7gCBMa/sD1igS2GHkHVIVnog3aghPvpdyvKDYY="
```
* PgBouncerサービスを再起動
```
net start pgbouncer
net stop pgbouncer
```
* PgBouncer経由でpostgresにアクセスできるか確認
```
C:\Users\masami>psql -U pgbouncer_user -p 6432 -d sample
Password for user pgbouncer_user:
psql (16.0)
WARNING: Console code page (65001) differs from Windows code page (932)
         8-bit characters might not work correctly. See psql reference
         page "Notes for Windows users" for details.
Type "help" for help.

sample=#
```


* pgbenchのセットアップ
```
C:\Users\masami>pgbench -i -U postgres -d sample
Password:
dropping old tables...
NOTICE:  テーブル"pgbench_accounts"は存在しません、スキップします
NOTICE:  テーブル"pgbench_branches"は存在しません、スキップします
NOTICE:  テーブル"pgbench_history"は存在しません、スキップします
NOTICE:  テーブル"pgbench_tellers"は存在しません、スキップします
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.03 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.38 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.21 s, vacuum 0.05 s, primary keys 0.11 s).
```
* PgBouncerをバイパスしないでロールでベンチマーキング
```
C:\Users\masami>pgbench -c 20 -t 100 -C -p 5432 -U postgres sample
Password:
pgbench (16.0)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
number of transactions per client: 100
number of transactions actually processed: 2000/2000
number of failed transactions: 0 (0.000%)
latency average = 1759.388 ms
average connection time = 85.458 ms
tps = 11.367589 (including reconnection times)
```
* PgBouncer経由でベンチマーキング
```
C:\Users\masami>pgbench -c 20 -t 100 -C -p 6432 -U pgbouncer_user sample
Password:
pgbench (16.0)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
number of transactions per client: 100
number of transactions actually processed: 2000/2000
number of failed transactions: 0 (0.000%)
latency average = 421.922 ms
average connection time = 20.137 ms
tps = 47.402174 (including reconnection times)
```


* コネクションに掛かる時間とレイテンシはおよそ4分の１になった。

* 一応、PgBouncerのログを確認する  
統計値を定期的(デフォルトでは1分おき)に書き込んでいるようです
```
2023-10-22 09:13:01.605 東京 (標準時) [11380] LOG stats: 33 xacts/s, 233 queries/s, in 14105 B/s, out 6227 B/s, xact 366616 us, query 45415 us, wait 143766 us
```

* 油断するとログの書き込み量が凄い勢いで増える。一応ログローテーションはするようです。
ログの大部分を占めるコネクション関係のログをなくす場合は下記設定にします。
```
;; log if client connects or server connection is made
log_connections = 0

;; log if and why connection was closed
log_disconnections = 0
```
あとは、PostgreSQLサービスを再起動した場合は、そのあとにPgBouncerサービスを再起動したほうが良さそうです（未調査)