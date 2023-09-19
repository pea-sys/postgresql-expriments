# Postgres インストール後の作業

忘れてしまうのでメモ

```
PS C:\Users\user> pg_test_fsync  -f test.txt
テスト１件あたり 5秒
このプラットフォームでは open_datasync と open_sync について O_DIRECT がサポートされています。

１個の 8kB write を使ってファイル同期メソッドを比較します:
（wal_sync_method の指定順の中で、Linux のデフォルトである fdatasync は除きます）
        open_datasync                      5853.025 操作/秒     171 マイクロ秒/操作
        fdatasync                           237.351 操作/秒    4213 マイクロ秒/操作
        fsync                               290.239 操作/秒    3445 マイクロ秒/操作
        fsync_writethrough                  285.255 操作/秒    3506 マイクロ秒/操作
        open_sync                                  利用不可

２個の 8kB write を使ってファイル同期メソッドを比較します:
（wal_sync_method の指定順の中で、Linux のデフォルトである fdatasync は除きます）
        open_datasync                      3203.336 操作/秒     312 マイクロ秒/操作
        fdatasync                           300.916 操作/秒    3323 マイクロ秒/操作
        fsync                               273.789 操作/秒    3652 マイクロ秒/操作
        fsync_writethrough                  284.944 操作/秒    3509 マイクロ秒/操作
        open_sync                                  利用不可

open_sync を異なった write サイズで比較します:
(これは open_sync の write サイズを変えながら、16kB write のコストを
比較するよう指定されています。)
         1 * 16kB open_sync write                  利用不可
         2 *  8kB open_sync writes                 利用不可
         4 *  4kB open_sync writes                 利用不可
         8 *  2kB open_sync writes                 利用不可
        16 *  1kB open_sync writes                 利用不可

書き込みなしのファイルディスクリプタ上の fsync の方が優れているかをテストします:
（もし実行時間が同等であれば、fsync() は異なったファイルディスクリプタ上で
データを sync できることになります。）
        write, fsync, close                  34.895 操作/秒   28657 マイクロ秒/操作
        write, close, fsync                  22.899 操作/秒   43670 マイクロ秒/操作

8kB の sync なし write:
        write                             54854.806 操作/秒      18 マイクロ秒/操作
```

秒あたりの操作数が最も多い値を postgres.conf に反映する

```
wal_sync_method = open_datasync
```

PGTune でメモリの設定  
https://pgtune.leopard.in.ua/

![1](https://github.com/pea-sys/postgresql-expriments/assets/49807271/0c90ae91-0a49-4596-9203-525010e9d98b)

```
# DB Version: 15
# OS Type: windows
# DB Type: desktop
# Total Memory (RAM): 6 GB
# CPUs num: 2
# Connections num: 20
# Data Storage: ssd

max_connections = 20
shared_buffers = 384MB
effective_cache_size = 1536MB
maintenance_work_mem = 384MB
checkpoint_completion_target = 0.9
wal_buffers = 11796kB
default_statistics_target = 100
random_page_cost = 1.1
work_mem = 8MB
huge_pages = off
min_wal_size = 100MB
max_wal_size = 2GB
```

後は実環境に合わせてチューニング
