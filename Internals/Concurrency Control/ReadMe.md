# 同時実行制御

- トランザクション ID  
  トランザクション ID はトランザクション開始で振られるわけでなく、トランザクション内でコマンドが発行された場合に加算される。  
  以下のケースの場合、SELECT でのみトランザクション ID が加算される。

```
postgres=# SELECT txid_current ();
 txid_current
--------------
         1179
(1 行)


postgres=# BEGIN;
BEGIN
postgres=*# COMMIT;
COMMIT
postgres=# BEGIN;
BEGIN
postgres=*# COMMIT;
COMMIT
postgres=# SELECT txid_current ();
 txid_current
--------------
         1180
(1 行)
```

- pageinspect  
  ページの内容を表示するための拡張機能 pageinspect がある。  
   postgres のタプルデータ構造を理解するのに便利なツール。

```
dvdrental=# CREATE EXTENSION pageinspect ;
CREATE EXTENSION
dvdrental=# INSERT INTO actor VALUES(9999,'first','last');
dvdrental=# SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid FROM heap_page_items(get_raw_page('actor',0));
 tuple | t_xmin | t_xmax | t_cid | t_ctid
-------+--------+--------+-------+--------
     1 |   1182 |      0 |     0 | (0,1)
     2 |   1183 |      0 |     0 | (0,2)
     3 |   1184 |      0 |     0 | (0,3)
(3 行)
dvdrental=# INSERT INTO actor VALUES(1000001,'first','last');
INSERT 0 1
dvdrental=# SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid FROM heap_page_items(get_raw_page('actor',0));
 tuple | t_xmin | t_xmax | t_cid | t_ctid
-------+--------+--------+-------+--------
     1 |   1182 |      0 |     0 | (0,1)
     2 |   1183 |      0 |     0 | (0,2)
     3 |   1184 |      0 |     0 | (0,3)
     4 |   1185 |      0 |     0 | (0,4)
(4 行)
dvdrental=# delete from actor where actor_id = 1000000;
DELETE 1
dvdrental=# SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid FROM heap_page_items(get_raw_page('actor',0));
 tuple | t_xmin | t_xmax | t_cid | t_ctid
-------+--------+--------+-------+--------
     1 |   1182 |      0 |     0 | (0,1)
     2 |   1183 |      0 |     0 | (0,2)
     3 |   1184 |   1242 |     0 | (0,3)
     4 |   1185 |      0 |     0 | (0,4)
(4 行)
dvdrental=# vacuum;
VACUUM
dvdrental=# SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid FROM heap_page_items(get_raw_page('actor',0));
 tuple | t_xmin | t_xmax | t_cid | t_ctid
-------+--------+--------+-------+--------
     1 |        |        |       |
     2 |        |        |       |
     3 |        |        |       |
     4 |   1185 |      0 |     0 | (0,4)
(4 行)
dvdrental=# update actor set first_name='last' where actor_id = 1000001;
UPDATE 1
dvdrental=# SELECT lp as tuple, t_xmin, t_xmax, t_field3 as t_cid, t_ctid FROM heap_page_items(get_raw_page('actor',0));
 tuple | t_xmin | t_xmax | t_cid | t_ctid
-------+--------+--------+-------+--------
     1 |        |        |       |
     2 |        |        |       |
     3 |        |        |       |
     4 |   1185 |   1244 |     0 | (0,5)
     5 |   1244 |   1244 |     0 | (0,5)
(5 行)
```

- pg_freespacemap  
  pg_freespacemap は、指定されたテーブル/インデックスの空き領域を提供します

```
dvdrental=# CREATE EXTENSION pg_freespacemap ;
CREATE EXTENSION
dvdrental=# SELECT *, round ( 100 * avail / 8192 , 2 ) as "freespace ratio" FROM pg_freespace ( 'actor' );
 blkno | avail | freespace ratio
-------+-------+-----------------
     0 |  8160 |           99.00
     1 |  8160 |           99.00
     2 |  8160 |           99.00
     3 |  8160 |           99.00
     4 |  8160 |           99.00
     5 |  8160 |           99.00
     6 |  8160 |           99.00
     7 |  8160 |           99.00
     8 |  8160 |           99.00
・・・
```

- pg_current_snapshot  
  pg_current_snapshot はトランザクションのスナップショットを取得します。出力は  
  active な最小の xactid : 次回割り当てる xactid : アクティブな xactlist

```
dvdrental=# SELECT pg_current_snapshot ();
 pg_current_snapshot
---------------------
 1246:1246:
(1 行)
dvdrental=# INSERT INTO actor VALUES(1000000,'first','last');
INSERT 0 1
dvdrental=# SELECT pg_current_snapshot ();
 pg_current_snapshot
---------------------
 1247:1247:
(1 行)
```

- SSI の実行方法

## 書き込みスキュー異常検出

### [トランザクション A]

```
dvdrental=# START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION
dvdrental=*# select * from tbl where id = 2000;
  id  | flag
------+------
 2000 | f
(1 行)


dvdrental=*# update tbl set flag = TRUE where id = 1;
UPDATE 1
dvdrental=*# COMMIT;
COMMIT
```

### [トランザクション B]

```
dvdrental=# START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION
dvdrental=*# select * from tbl where id = 1;
 id | flag
----+------
  1 | f
(1 行)


dvdrental=*# update tbl set flag = TRUE where id = 2000;
UPDATE 1
dvdrental=*# COMMIT;
ERROR:  トランザクション間で read/write の依存性があったため、アクセスの直列化ができませんでした
DETAIL:  Reason code: Canceled on identification as a pivot, during commit attempt.
HINT:  リトライが行われた場合、このトランザクションは成功するかもしれません
```

## 偽陽性のシリアル化異常が発生するシナリオ

### [トランザクション A]

```
dvdrental=# START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION
dvdrental=*# select * from tbl where id = 1;
 id | flag
----+------
  1 | t
(1 行)


dvdrental=*# update tbl set flag = TRUE where id = 1;
UPDATE 1
dvdrental=*# COMMIT;
COMMIT
```

### [トランザクション B]

```
dvdrental=#  START TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION
dvdrental=*# select * from tbl where id = 2;
 id | flag
----+------
  2 | f
(1 行)


dvdrental=*# update tbl set flag = TRUE where id = 2;
UPDATE 1
dvdrental=*# COMMIT;
COMMIT
```
