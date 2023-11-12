# PostgreSQLのUNLOGGEDのパフォーマンス

UNLOGGEDテーブルはWALログ書き出しをしないため、高速であるとされています。  
以下、公式ドキュメント抜粋。
```
UNLOGGED
指定された場合、テーブルはログを取らないテーブルとして作成されます。 ログを取らないテーブルに書き出されたデータは先行書き込みログ（30章信頼性とログ先行書き込み参照）には書き出されません。 このため通常のテーブルより相当高速になります。 しかしこれらはクラッシュ時に安全ではありません。 クラッシュまたは異常停止の後、ログを取らないテーブルは自動的に切り詰められます。 またログを取らないテーブルの内容はスタンバイサーバに複製されません。 ログを取らないテーブル上に作成されたインデックスはすべて同様に、ログを取らないようになります。
```
今回は通常のテーブルとのパフォーマンス比較を行いました。  
結果としてはUNLOGGEDは3割~4割早い。

||LOGGED|UNLOGGED|
|--|--|--|
|TPS|1804.942301|2444.849542|

### 準備
```
createdb -U postgres sample
```

### LOGGEDテーブル
```
pgbench -U postgres -i sample
pgbench -U postgres -c 10 -t 100000 sample
Password:
pgbench (16.0)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 10
number of threads: 1
maximum number of tries: 1
number of transactions per client: 100000
number of transactions actually processed: 1000000/1000000
number of failed transactions: 0 (0.000%)
latency average = 5.540 ms
initial connection time = 687.877 ms
tps = 1804.942301 (without initial connection time)
```

### UNLOGGEDテーブル
```sql
pgbench -U postgres -i sample
psql -U postgres -d sample
sample=# alter table pgbench_accounts set unlogged;
ALTER TABLE
sample=# alter table pgbench_branches set unlogged;
ALTER TABLE
sample=# alter table pgbench_history set unlogged;
ALTER TABLE
sample=# alter table pgbench_tellers set unlogged;
sample=# exit
pgbench -U postgres -c 10 -t 100000 sample
Password:
pgbench (16.0)
starting vacuum...end.
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 10
number of threads: 1
maximum number of tries: 1
number of transactions per client: 100000
number of transactions actually processed: 1000000/1000000
number of failed transactions: 0 (0.000%)
latency average = 4.090 ms
initial connection time = 692.264 ms
tps = 2444.849542 (without initial connection time)
```