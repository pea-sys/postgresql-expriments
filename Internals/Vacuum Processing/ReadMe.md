# VACUUM Processing

## ■pg_class.relfrozenxid と pg_database.datfrozenxid を表示する方法

```
dvdrental=# VACUUM tbl;
VACUUM
dvdrental=# SELECT n.nspname as "Schema", c.relname as "Name", c.relfrozenxid
dvdrental-#              FROM pg_catalog.pg_class c
dvdrental-#              LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
dvdrental-#              WHERE c.relkind IN ('r','')
dvdrental-#                    AND n.nspname <> 'information_schema' AND n.nspname !~ '^pg_toast'
dvdrental-#                    AND pg_catalog.pg_table_is_visible(c.oid)
dvdrental-#                    ORDER BY c.relfrozenxid::text::bigint DESC;
   Schema   |           Name           | relfrozenxid
------------+--------------------------+--------------
 public     | tbl                      |         1254
 public     | film_actor               |         1244
 pg_catalog | pg_language              |         1244
 pg_catalog | pg_largeobject_metadata  |         1244
 pg_catalog | pg_statistic_ext         |         1244
 pg_catalog | pg_event_trigger         |         1244
 pg_catalog | pg_cast                  |         1244
 pg_catalog | pg_namespace             |         1244
 pg_catalog | pg_conversion            |         1244
 pg_catalog | pg_db_role_setting       |         1244
 pg_catalog | pg_auth_members          |         1244
 pg_catalog | pg_shdepend              |         1244
 pg_catalog | pg_ts_config             |         1244
 pg_catalog | pg_ts_config_map         |         1244
 pg_catalog | pg_ts_dict               |         1244
 pg_catalog | pg_ts_parser             |         1244
 pg_catalog | pg_ts_template           |         1244
 pg_catalog | pg_foreign_data_wrapper  |         1244
 pg_catalog | pg_foreign_server        |         1244
 pg_catalog | pg_policy                |         1244
 pg_catalog | pg_replication_origin    |         1244
 pg_catalog | pg_default_acl           |         1244
 pg_catalog | pg_init_privs            |         1244
 pg_catalog | pg_seclabel              |         1244
 pg_catalog | pg_shseclabel            |         1244
 pg_catalog | pg_collation             |         1244
 pg_catalog | pg_parameter_acl         |         1244
 pg_catalog | pg_partitioned_table     |         1244
 pg_catalog | pg_range                 |         1244
 pg_catalog | pg_transform             |         1244
 pg_catalog | pg_publication           |         1244
 pg_catalog | pg_publication_namespace |         1244
 pg_catalog | pg_publication_rel       |         1244
 pg_catalog | pg_subscription_rel      |         1244
 pg_catalog | pg_largeobject           |         1244
 pg_catalog | pg_foreign_table         |         1244
 pg_catalog | pg_authid                |         1244
 pg_catalog | pg_statistic_ext_data    |         1244
 public     | sample_tbl               |         1244
 pg_catalog | pg_user_mapping          |         1244
 pg_catalog | pg_subscription          |         1244
 pg_catalog | pg_inherits              |         1244
 pg_catalog | pg_operator              |         1244
 pg_catalog | pg_opfamily              |         1244
 pg_catalog | pg_opclass               |         1244
 pg_catalog | pg_am                    |         1244
 pg_catalog | pg_amop                  |         1244
 pg_catalog | pg_amproc                |         1244
 pg_catalog | pg_description           |         1181
 pg_catalog | pg_extension             |         1181
 pg_catalog | pg_tablespace            |         1164
 public     | actor                    |          929
 pg_catalog | pg_statistic             |          918
 pg_catalog | pg_trigger               |          880
 public     | store                    |          834
 public     | staff                    |          833
 public     | rental                   |          832
 public     | payment                  |          831
 public     | language                 |          830
 public     | inventory                |          829
 public     | film_category            |          828
 public     | film                     |          826
 public     | customer                 |          825
 public     | country                  |          824
 public     | city                     |          823
 public     | category                 |          822
 public     | address                  |          821
 pg_catalog | pg_rewrite               |          770
 pg_catalog | pg_index                 |          764
 pg_catalog | pg_aggregate             |          753
 pg_catalog | pg_attrdef               |          750
 pg_catalog | pg_attribute             |          748
 pg_catalog | pg_class                 |          748
 pg_catalog | pg_sequence              |          748
 pg_catalog | pg_proc                  |          740
 pg_catalog | pg_constraint            |          739
 pg_catalog | pg_type                  |          738
 pg_catalog | pg_enum                  |          738
 pg_catalog | pg_depend                |          738
 pg_catalog | pg_shdescription         |          722
 pg_catalog | pg_database              |          720
(81 行)


dvdrental=# SELECT datname, datfrozenxid FROM pg_database WHERE datname = 'dvdrental';
  datname  | datfrozenxid
-----------+--------------
 dvdrental |          720
(1 行)
```

## ■pg_database.datfrozenxid と clog ファイル

```
dvdrental=# SELECT datname, datfrozenxid FROM pg_database;
  datname  | datfrozenxid
-----------+--------------
 postgres  |          717
 dvdrental |          720
 template1 |          717
 template0 |          717
(4 行)

PS C:\Program Files\PostgreSQL\15\data\pg_xact> ls

    Directory: C:\Program Files\PostgreSQL\15\data\pg_xact

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a---          2023/04/29     6:59           8192 0000
```

## ■pg_freespacemap

VACUUM FULL の実行タイミングを見極める方法として pg_freespacemap を使用する方法がある。

```
dvdrental=# CREATE EXTENSION pg_freespacemap ;
ERROR:  機能拡張"pg_freespacemap"はすでに存在します
dvdrental=# SELECT count(*) as "number of pages",
dvdrental-#        pg_size_pretty(cast(avg(avail) as bigint)) as "Av. freespace size",
dvdrental-#        round(100 * avg(avail)/8192 ,2) as "Av. freespace ratio"
dvdrental-#        FROM pg_freespace('tbl');
 number of pages | Av. freespace size | Av. freespace ratio
-----------------+--------------------+---------------------
               9 | 135 bytes          |                1.65
```

空き領域が 1.65%しかありません。

```
dvdrental=# delete from tbl where id < 500;
DELETE 499
dvdrental=# vacuum tbl;
VACUUM
dvdrental=# SELECT count(*) as "number of pages",
dvdrental-#        pg_size_pretty(cast(avg(avail) as bigint)) as "Av. freespace size",
dvdrental-#        round(100 * avg(avail)/8192 ,2) as "Av. freespace ratio"
dvdrental-#        FROM pg_freespace('tbl');
 number of pages | Av. freespace size | Av. freespace ratio
-----------------+--------------------+---------------------
               9 | 2119 bytes         |               25.87
(1 行)
```

タプルを削除して VACUUM コマンドを実行すると空き容量が増えます。

```
dvdrental=# SELECT *, round ( 100 * avail / 8192 , 2 ) as "freespace ratio"
dvdrental-#                 FROM pg_freespace ( 'tbl' );
 blkno | avail | freespace ratio
-------+-------+-----------------
     0 |  8160 |           99.00
     1 |  8160 |           99.00
     2 |  1504 |           18.00
     3 |     0 |            0.00
     4 |     0 |            0.00
     5 |     0 |            0.00
     6 |     0 |            0.00
     7 |     0 |            0.00
     8 |  1248 |           15.00
```

指定テーブルの各ページファイルの空き領域を調べます。

```
dvdrental=# VACUUM FULL tbl;
VACUUM
dvdrental=# SELECT count(*) as "number of blocks",
dvdrental-#        pg_size_pretty(cast(avg(avail) as bigint)) as "Av. freespace size",
dvdrental-#        round(100 * avg(avail)/8192 ,2) as "Av. freespace ratio"
dvdrental-#        FROM pg_freespace('tbl');
 number of blocks | Av. freespace size | Av. freespace ratio
------------------+--------------------+---------------------
                7 | 0 bytes            |                0.00
(1 行)

dvdrental=# SELECT *, round ( 100 * avail / 8192 , 2 ) as "freespace ratio"
dvdrental-#                 FROM pg_freespace ( 'tbl' );
 blkno | avail | freespace ratio
-------+-------+-----------------
     0 |     0 |            0.00
     1 |     0 |            0.00
     2 |     0 |            0.00
     3 |     0 |            0.00
     4 |     0 |            0.00
     5 |     0 |            0.00
     6 |     0 |            0.00
(7 行)
```

VACUUM FULL を使用するページファイルが減りデータ領域が圧縮されることが分かります。
