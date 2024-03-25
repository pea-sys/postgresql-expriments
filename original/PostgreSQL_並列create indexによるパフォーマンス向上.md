PostgreSQL 11 以降、インデックスを並行して作成できるようになりました

## 環境

並列化の有効値を確認  
4 つまで並列化できそうです

```sh
set NUMBER_OF_PROCESSORS
NUMBER_OF_PROCESSORS=4
```

OS のバージョン

```sh
Windows11 22H2
```

PostgreSQL のバージョン

```
psql (16.2)
```

データベース作成

```sh
createdb -U postgres sample
psql -U postgres -d sample
```

インデックス作成用のメモリ確認

```sql
sample=# show maintenance_work_mem;
 maintenance_work_mem
----------------------
 384MB
```

データ作成

```sql
sample=# create table t_demo (data numeric);
CREATE TABLE
sample=# create or replace procedure insert_data(buckets integer)
language plpgsql
as $$
    declare
        i int;
    begin
        i := 0;
        while i < buckets loop
            insert into t_demo select random()
            from generate_series(1, 1000000);
            i := i+ 1;
            raise notice 'inserted % buckets', i;
            commit;
        end loop;
        return;
    end;
$$;
CREATE PROCEDURE
sample=# call insert_data(10);
NOTICE:  inserted 1 buckets
NOTICE:  inserted 2 buckets
NOTICE:  inserted 3 buckets
NOTICE:  inserted 4 buckets
NOTICE:  inserted 5 buckets
NOTICE:  inserted 6 buckets
NOTICE:  inserted 7 buckets
NOTICE:  inserted 8 buckets
NOTICE:  inserted 9 buckets
NOTICE:  inserted 10 buckets
CALL
```

データサイズは約 400MB です  
行数の多いテーブルでインデックス作成をする場合、`vmstat`を見るとディスク I/O がボトルネックになっており、並列化の効果がほとんどなかったため、やや小さめのテーブルで実験しています。

```sh
sample=# \dt+
                                  リレーション一覧
 スキーマ |  名前  |  タイプ  |  所有者  | 永続性 | アクセスメソッド | サイズ | 説明
----------+--------+----------+----------+--------+------------------+--------+------
 public   | t_demo | テーブル | postgres | 永続   | heap             | 422 MB |
(1 行)
```

インデックス作成はデフォルトで 2 スレッドが使用されます

```sql
sample=# show max_parallel_maintenance_workers;
 max_parallel_maintenance_workers
----------------------------------
 2
(1 行)
```

測定オプションの有効化

```
sample=# \timing
タイミングは on です。
```

1 スレッドでインデックス作成

```sql
sample=# set max_parallel_maintenance_workers = 0;
SET
時間: 1.551 ミリ秒
sample=# create index idx1 on t_demo (data);
CREATE INDEX
時間: 13741.046 ミリ秒(00:13.741)
sample=# vacuum analyze;
VACUUM
時間: 417.732 ミリ秒
```

2 スレッドでインデックス作成

```Sql
sample=# set max_parallel_maintenance_workers = 2;
SET
時間: 0.287 ミリ秒
sample=# create index idx2 on t_demo (data);
CREATE INDEX
時間: 11371.870 ミリ秒(00:11.372)
sample=# vacuum analyze;
VACUUM
時間: 552.416 ミリ秒
```

3 スレッドでインデックス作成

```sql
sample=# SET max_parallel_maintenance_workers TO 3;
SET
時間: 0.264 ミリ秒
sample=# create index idx3 ON t_demo (data);
CREATE INDEX
時間: 10407.165 ミリ秒(00:10.407)
sample=# vacuum analyze;
VACUUM
時間: 571.138 ミリ秒
```

4 スレッドでインデックス作成

```sql
sample=# SET max_parallel_maintenance_workers TO 4;
SET
時間: 0.272 ミリ秒
sample=# CREATE INDEX idx5 ON t_demo (data);
CREATE INDEX
時間: 11125.595 ミリ秒(00:11.126)
sample=# vacuum analyze;
VACUUM
時間: 653.285 ミリ秒
```

5 スレッド以降もほとんど同様のパフォーマンスであり、3 スレッドで頭打ちでした。
サーバプロセスが１つのスレッドを占有しているため、3 スレッドを超えた場合は、コンテキストスイッチによるオーバーヘッドが発生しているものと推測されます。

ちなみにテーブル毎に使用するスレッド数を変えたい場合は、`alter table`で指定可能です。

```sql
alter table t_demo set (parallel_workers = 4);
```

また、８スレッド以上使用する場合は、次の設定も８以上に変更する必要があります。

```sql
sample=# show max_worker_processes;
 max_worker_processes
----------------------
 8
(1 行)
sample=# show max_parallel_workers;
 max_parallel_workers
----------------------
 8
(1 行)
```

次の記事により細かい内容が記載されています。  
ディスク I/O に関しても対策が記載されています。

https://www.cybertec-postgresql.com/en/postgresql-parallel-create-index-for-better-performance/
