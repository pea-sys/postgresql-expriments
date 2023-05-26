# WAL

### ■WAL セグメント ファイル名を見つける

指定した LSN を含む WAL ファイルを検索する

```
dvdrental=# SELECT pg_walfile_name('1/00002D3E');
     pg_walfile_name
--------------------------
 000000010000000100000000
(1 行)
```

### ■WAL の圧縮

バージョン 9.5 以降は設定ファイルの wal_compression を on にすることで wal を圧縮できる。  
デフォルトは off になっている。on にすることで i/o コストが減るが  
cpu パワーを必要とする。  
下記例では wal_compression = on にすると約 7 割のデータサイズ削減をしている。

[wal_compression = on]

```pwsh
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
PS C:\Program Files\PostgreSQL\15\data\pg_wal> pgbench -i -s 100 -U postgres -d sample
Password:
dropping old tables...
NOTICE:  繝・・繝悶Ν"pgbench_accounts"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_branches"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_history"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
NOTICE:  繝・・繝悶Ν"pgbench_tellers"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
creating tables...
generating data (client-side)...
10000000 of 10000000 tuples (100%) done (elapsed 43.83 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 71.63 s (drop tables 0.01 s, create tables 0.02 s, client-side generate 48.19 s, vacuum 4.14 s, primary keys 19.27 s).
PS C:\Program Files\PostgreSQL\15\data\pg_wal> psql -U postgres -p 5432 -d sample
ユーザー postgres のパスワード:
psql (15.2)
"help"でヘルプを表示します。

sample=# CHECKPOINT;
CHECKPOINT
sample=# select pg_current_wal_lsn();
 pg_current_wal_lsn
--------------------
 0/6499EB08
(1 行)

pgbench -U postgres -t 40000 -c 4 -d sample

sample=# select pg_current_wal_lsn();
 pg_current_wal_lsn
--------------------
 0/83C19508
(1 行)

sample=# SELECT pg_wal_lsn_diff('0/83C19508','0/6499EB08');
 pg_wal_lsn_diff
-----------------
       522693120
(1 行)
```

[wal_compression = off]

```pwsh
PS C:\Program Files\PostgreSQL\15\data\pg_wal> psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
ユーザー postgres のパスワード:
CREATE DATABASE
PS C:\Program Files\PostgreSQL\15\data\pg_wal> pgbench -i -s 100 -U postgres -d sample
Password:
dropping old tables...
NOTICE:  繝・・繝悶Ν"pgbench_accounts"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_branches"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_history"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
NOTICE:  繝・・繝悶Ν"pgbench_tellers"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
creating tables...
generating data (client-side)...
10000000 of 10000000 tuples (100%) done (elapsed 56.78 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 73.52 s (drop tables 0.01 s, create tables 0.02 s, client-side generate 60.03 s, vacuum 0.79 s, primary keys 12.68 s).
sample=# CHECKPOINT;
CHECKPOINT
sample=# select pg_current_wal_lsn();
 pg_current_wal_lsn
--------------------
 0/D0CB9528
(1 行)

pgbench -U postgres -t 40000 -c 4 -d sample

PS C:\Program Files\PostgreSQL\15\data\pg_wal> psql -U postgres -p 5432 -d sample
ユーザー postgres のパスワード:
psql (15.2)
"help"でヘルプを表示します。

sample=# select pg_current_wal_lsn();
 pg_current_wal_lsn
--------------------
 1/40E142E8
(1 行)

sample=# SELECT pg_wal_lsn_diff('1/40E142E8','0/D0CB9528');
 pg_wal_lsn_diff
-----------------
      1880468928
(1 行)
```

### ■pg_control の内容表示

pg_control ファイルは、ベース ディレクトリの下のグローバル サブディレクトリに保存されます。その内容は、 pg_controldata ユーティリティを使用して表示できます。

```
C:\Users\user>pg_controldata
pg_controlバージョン番号:                    1300
カタログバージョン番号:                      202209061
データベースシステム識別子:                  7225443098701613784
データベースクラスタの状態:                  運用中
pg_control最終更新:                          2023/04/30 12:09:52
最終チェックポイント位置:                    1/40E14238
最終チェックポイントのREDO位置:              1/381A31F0
最終チェックポイントのREDO WALファイル:      000000010000000100000038
最終チェックポイントの時系列ID:              1
最終チェックポイントのPrevTimeLineID:        1
最終チェックポイントのfull_page_writes:      オン
最終チェックポイントのNextXID:               0:308140
最終チェックポイントのNextOID:               25071
最終チェックポイントのNextMultiXactId:       1
最終チェックポイントのNextMultiOffset:       0
最終チェックポイントのoldestXID:             717
最終チェックポイントのoldestXIDのDB:         5
最終チェックポイントのoldestActiveXID:       308139
最終チェックポイントのoldestMultiXid:        1
最終チェックポイントのoldestMultiのDB:       16398
最終チェックポイントのoldestCommitTsXid:     0
最終チェックポイントのnewestCommitTsXid:     0
最終チェックポイント時刻:                    2023/04/30 12:05:22
UNLOGGEDリレーションの偽のLSNカウンタ:       0/3E8
最小リカバリ終了位置:                        0/0
最小リカバリ終了位置のタイムライン:          0
バックアップ開始位置:                        0/0
バックアップ終了位置:                        0/0
必要なバックアップ最終レコード:              いいえ
wal_levelの設定:                             replica
wal_log_hintsの設定:                         オフ
max_connectionsの設定:                       100
max_worker_processesの設定:                  8
max_wal_sendersの設定:                       10
max_prepared_xactsの設定:                    0
max_locks_per_xactの設定:                    64
track_commit_timestampの設定:                オフ
最大データアラインメント:                    8
データベースのブロックサイズ:                8192
大きなリレーションのセグメント毎のブロック数:131072
WALのブロックサイズ:                         8192
WALセグメント当たりのバイト数:               16777216
識別子の最大長:                              64
インデックス内の最大列数:                    32
TOASTチャンクの最大サイズ:                   1996
ラージオブジェクトチャンクのサイズ:          2048
日付/時刻型の格納方式:                       64ビット整数
Float8引数の渡し方:                          値渡し
データベージチェックサムのバージョン:        0
認証用の疑似nonce:                           c2def625323584495598a6caff8d1fa05ce55371a7a8f4743bc6da560b4dd0a5
```
