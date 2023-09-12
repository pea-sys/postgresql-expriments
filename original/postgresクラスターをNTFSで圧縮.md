# postgres クラスターを NTFS で圧縮

```
PS C:\Users\user> psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
PS C:\Users\user>  pgbench -U postgres --initialize --scale=10 sample
```

Windows 環境で base フォルダを NTFS の圧縮機能の対象とした場合のパフォーマンスの差異を見ます。

### [NTFS なし]※クラスターサイズ：580 MB

```
PS C:\Users\user> pgbench -c 10 -t 1000 -U postgres -d sample
・・・
number of transactions per client: 1000
number of transactions actually processed: 10000/10000
number of failed transactions: 0 (0.000%)
latency average = 213.788 ms
initial connection time = 1965.217 ms
tps = 46.775241 (without initial connection time)
PS C:\Users\user> psql -U postgres -d sample
ユーザー postgres のパスワード:
psql (16rc1)
"help"でヘルプを表示します。

sample=# vacuum full;
VACUUM
sample=# analyze;
ANALYZE
```

### [NTFS あり(base フォルダのみ)]※クラスターサイズ：445 MB (466,706,432 バイト)

![1](https://github.com/pea-sys/postgresql-expriments/assets/49807271/8519cf82-cb50-4626-b056-9caf12caa170)

```
PS C:\Users\user> pgbench -c 10 -t 1000 -U postgres -d sample
・・・
number of transactions per client: 1000
number of transactions actually processed: 10000/10000
number of failed transactions: 0 (0.000%)
latency average = 249.701 ms
initial connection time = 2501.168 ms
tps = 40.047927 (without initial connection time)
PS C:\Users\user> psql -U postgres -d sample
ユーザー postgres のパスワード:
psql (16rc1)
"help"でヘルプを表示します。

sample=# vacuum full;
VACUUM
sample=# analyze;
ANALYZE
```

### [NTFS あり(クラスター全体)]※クラスターサイズ：144 MB (151,695,360 バイト)

```
PS C:\Users\user> pgbench -c 10 -t 1000 -U postgres -d sample
・・・
number of transactions per client: 1000
number of transactions actually processed: 10000/10000
number of failed transactions: 0 (0.000%)
latency average = 200.936 ms
initial connection time = 1563.955 ms
tps = 49.767109 (without initial connection time)
PS C:\Users\user> psql -U postgres -d sample
ユーザー postgres のパスワード:
psql (16rc1)
"help"でヘルプを表示します。

sample=# vacuum full;
VACUUM
sample=# analyze;
ANALYZE
```

結論としてはパフォーマンスに差異はなさそう。
そして、圧縮効果が思いのほか大きい。  
Windows 環境で DB クラスターを圧縮しない理由が特に見つからないのですが、圧縮・伸長は行っているので、トレードオフはあるはず。
