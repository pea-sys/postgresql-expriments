# データベース クラスタ、データベース、およびテーブル

https://www.interdb.jp/pg/pgsql01.html

上記のページの内容をハンズオンで確認していきます。  
使用するデータベースは以下から拝借します。

https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/

- 1. ダウンロードした zip ファイルを解凍してダンプファイルをリストアします。

```pwsh
PS C:\Users\user> psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE dvdrental TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
CREATE DATABASE
PS C:\Users\user> pg_restore -U postgres -d dvdrental ./dvdrental.tar
```

- 2. dvdrental データベースに接続

```pwsh
PS C:\Users\user> psql -U postgres -p 5432 -d dvdrental
```

- 3. データベースとテーブルのオブジェクト id 確認

```pwsh
dvdrental=# SELECT datname , oid FROM pg_database WHERE datname = 'dvdrental' ;
  datname  |  oid
-----------+-------
 dvdrental | 16398
(1 行)

dvdrental=# SELECT relname , oid FROM pg_class WHERE relname = 'actor' ;
 relname |  oid
---------+-------
 actor   | 16433
(1 行)
```

- 4. ファイル構造の確認

```pwsh
PS C:\Users\user> cd "C:\Program Files\PostgreSQL\15\data\base"
```

- 5. データベースファイルの確認

```pwsh
PS C:\Program Files\PostgreSQL\15\data\base> ls

    Directory: C:\Program Files\PostgreSQL\15\data\base

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----          2023/04/24    20:51                1
d----          2023/04/24    20:52                16398
d----          2023/04/24    11:49                4
d----          2023/04/24    11:52                5
```

- 6. テーブルのオブジェクト ID と relfilenode を表示  
     データファイルは変数 relfilenode で管理されます。

```psql
dvdrental=# SELECT relname , oid , relfilenode FROM pg_class WHERE relname = 'actor' ;
 relname |  oid  | relfilenode
---------+-------+-------------
 actor   | 16433 |       16433
(1 行)
```

- 7. テーブルファイルの存在確認

```pwsh
PS C:\Program Files\PostgreSQL\15\data\base> Test-Path 16398\16433
True
```

- 8. relfilenode 値は、いくつかのコマンド (TRUNCATE、REINDEX、CLUSTER など) を発行することによって変更されます。  
     truncate することによって 16433 から 16712 に変更されています。

```pwsh
dvdrental=# TRUNCATE actor CASCADE;
NOTICE:  テーブル"film_actor"へのカスケードを削除します
TRUNCATE TABLE
dvdrental=# SELECT relname , oid , relfilenode FROM pg_class WHERE relname = 'actor' ;
 relname |  oid  | relfilenode
---------+-------+-------------
 actor   | 16433 |       16712
 dvdrental=# SELECT pg_relation_filepath ( 'actor' );
 pg_relation_filepath
----------------------
 base/16398/16712
```

- 9. 適当にテーブルにデータを作成します。  
     そうすると 16712.fsm ファイルが生成されます。

```
dvdrental=# insert into actor(actor_id, first_name, last_name) select  i,  format('actor_%s', i),  format('actor_%s', i) from generate_series(1, 100000) as i;
INSERT 0 100000
```

- 10.適当にテーブルからデータを削除します。  
  そうすると 16712.vm ファイルが生成されます。

```
dvdrental=# delete from actor where actor_id / 2 = 1;
DELETE 2
```

- 11. データベースフォルダ配下のテーブル関連ファイルは次のようになっています

```pwsh
PS C:\Program Files\PostgreSQL\15\data\base\16398> Get-ChildItem 16712*

    Directory: C:\Program Files\PostgreSQL\15\data\base\16398

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---          2023/04/24    22:25      117112832 16712
-a---          2023/04/24    22:21          49152 16712_fsm
-a---          2023/04/24    22:22           8192 16712_vm
```

- 12.テーブルスペースの作成

```
dvdrental=# CREATE TABLESPACE dbspace LOCATION 'E:\dbs';
CREATE TABLESPACE
```

- 13.新しく作成したテーブルスペースにテーブル作成

```
dvdrental=# CREATE TABLE sample_tbl (sample_id integer) TABLESPACE dbspace ;
CREATE TABLE
```

- 14.ファイルパスの取得

```
dvdrental=# SELECT pg_relation_filepath ( 'sample_tbl' );
            pg_relation_filepath
---------------------------------------------
 pg_tblspc/16771/PG_15_202209061/16398/16772
(1 行)
```
