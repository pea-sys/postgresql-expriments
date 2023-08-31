# MVCC の確認

次のウェビナー動画で紹介されていたスクリプトを元に MVCC の動作確認を行います。

---

2021 年 11 月 10 日（水）第 1 回セッション録画
MVCC の詳細と PostgreSQL のトランザクション処理〜その１〜  
https://edbjapan.com/postgresql-technical-webinar-announcement/

スクリプトの提供元  
https://momjian.us/main/  
ウェビナーの本流  
https://momjian.us/main/writings/pgsql/mvcc.pdf

---

### 予備知識

- xmin: 作成トランザクション番号。INSERT と UPDATE で設定される。
- xmax: UPDATE と DELETE で設定される期限切れトランザクション番号。
  明示的な行ロックにも使用される。
- cmin/cmax: タプルを作成または期限切れにしたコマンド番号を識別するために使用される；
  また、タプルが同じトランザクションで作成され、期限切れになった場合、コンボコマンド ID を格納するためにも使用されます。
  また、明示的な行ロックにも使用される。

---

### [Setup]

mvcc テーブルを読み書きし、都度、mvcc_demo_page0 ビューで MVCC の状況を確認する。

```sql
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE mvcc TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
psql -U postgres -p 5432 -d mvcc
mvcc=# \pset footer off
mvcc=# \pset null (null)
Null表示は"(null)"です。
mvcc=# CREATE TABLE mvcc_demo (val INTEGER);
CREATE TABLE
mvcc=#
mvcc=# DROP VIEW IF EXISTS mvcc_demo_page0;
NOTICE:  ビュー"mvcc_demo_page0"は存在しません、スキップします
DROP VIEW
mvcc=#
mvcc=# CREATE EXTENSION pageinspect;
CREATE EXTENSION
mvcc=#
mvcc=# CREATE EXTENSION pg_freespacemap;
CREATE EXTENSION
mvcc=#
mvcc=# CREATE VIEW mvcc_demo_page0 AS
mvcc-#         SELECT  '(0,' || lp || ')' AS ctid,
mvcc-#                 CASE lp_flags
mvcc-#                         WHEN 0 THEN 'Unused'
mvcc-#                         WHEN 1 THEN 'Normal'
mvcc-#                         WHEN 2 THEN 'Redirect to ' || lp_off
mvcc-#                         WHEN 3 THEN 'Dead'
mvcc-#                 END,
mvcc-#                 t_xmin::text::int8 AS xmin,
mvcc-#                 t_xmax::text::int8 AS xmax,
mvcc-#                 t_ctid
mvcc-#         FROM heap_page_items(get_raw_page('mvcc_demo', 0))
mvcc-#         ORDER BY lp;
CREATE VIEW
```

### [INSERT Using Xmin]

```sql
mvcc=# INSERT INTO mvcc_demo VALUES (1);
SELECT xmin, xmax, * FROM mvcc_demo;
INSERT 0 1
  xmin  | xmax | val
--------+------+-----
 322568 |    0 |   1
```

### [DELETE Using Xmax]

```sql
mvcc=# DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);SELECT xmin, xmax, * FROM mvcc_demo;
DELETE 1
INSERT 0 1
  xmin  | xmax | val
--------+------+-----
 322570 |    0 |   1
```

### [DELETE Using Xmax]

```sql
mvcc=# DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);SELECT xmin, xmax, * FROM mvcc_demo;
DELETE 1
INSERT 0 1
  xmin  | xmax | val
--------+------+-----
 322570 |    0 |   1


mvcc=# BEGIN WORK;DELETE FROM mvcc_demo;
SELECT xmin, xmax, * FROM mvcc_demo;
BEGIN
DELETE 1
 xmin | xmax | val
------+------+-----

            -- 別コネクション
            mvcc=# SELECT xmin, xmax, * FROM mvcc_demo;
            xmin  |  xmax  | val
            --------+--------+-----
            322570 | 322571 |   1


mvcc=*# SELECT txid_current();
COMMIT WORK;
 txid_current
--------------
       322571


COMMIT
```

### [UPDATE Using Xmin and Xmax]

```sql
mvcc=# DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);SELECT xmin, xmax, * FROM mvcc_demo;
BEGIN WORK;
UPDATE mvcc_demo SET val = 2;
SELECT xmin, xmax, * FROM mvcc_demo;
DELETE 0
INSERT 0 1
  xmin  | xmax | val
--------+------+-----
 322572 |    0 |   1


BEGIN
UPDATE 1
  xmin  | xmax | val
--------+------+-----
 322573 |    0 |   2


                -- 別コネクション
                mvcc=# SELECT xmin, xmax, * FROM mvcc_demo;
                xmin  |  xmax  | val
                --------+--------+-----
                322572 | 322573 |   1

mvcc=*# COMMIT WORK;
COMMIT
```

### [Aborted Transaction IDs Remain]

トランザクションのロールバックは、トランザクション ID を中止したものとしてマークする。すべてのセッションはこのようなトランザクションを無視します。

```sql
mvcc=# DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);
BEGIN WORK;DELETE FROM mvcc_demo;
ROLLBACK WORK;SELECT xmin, xmax, * FROM mvcc_demo;
DELETE 1
INSERT 0 1
BEGIN
DELETE 1
ROLLBACK
  xmin  |  xmax  | val
--------+--------+-----
 322575 | 322576 |   1
```

### [Row Locks Using Xmax]

xmax が有効期限切れの xid ではなくロックの xid であることを示すために使用される。

```sql
mvcc=# DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);
BEGIN WORK;
DELETE FROM mvcc_demo;
ROLLBACK WORK;
SELECT xmin, xmax, * FROM mvcc_demo;
DELETE 1
INSERT 0 1
BEGIN
DELETE 1
ROLLBACK
  xmin  |  xmax  | val
--------+--------+-----
 322578 | 322579 |   1
mvcc=# DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);
BEGIN WORK;
SELECT xmin, xmax, * FROM mvcc_demo;
DELETE 1
INSERT 0 1
BEGIN
  xmin  | xmax | val
--------+------+-----
 322581 |    0 |   1
mvcc=# SELECT xmin, xmax, * FROM mvcc_demo FOR UPDATE;
  xmin  | xmax | val
--------+------+-----
 322581 |    0 |   1
mvcc=# SELECT xmin, xmax, * FROM mvcc_demo;
COMMIT WORK;
  xmin  |  xmax  | val
--------+--------+-----
 322581 | 322582 |   1
COMMIT
```

## Multi-Statement Transactions

複数ステートメント・トランザクションは、各ステートメントに独自の可視化ルールがあるため、特別な追跡が必要です。
可視性ルールがあるからです。例えば、カーソルの内容は、同じトランザクションの後のステートメントが行を変更しても、変更されないままでなければなりません。
ステートメントが行を変更しても、カーソルの内容は変更されません。このような追跡は
システムコマンド ID 列 cmin/cmax を使用して実装されます。

### [INSERT Using Cmin]

```sql
mvcc=# DELETE FROM mvcc_demo;
BEGIN WORK;INSERT INTO mvcc_demo VALUES (1);
INSERT INTO mvcc_demo VALUES (2);
INSERT INTO mvcc_demo VALUES (3);SELECT xmin, cmin, xmax, * FROM mvcc_demo;
COMMIT WORK;
DELETE 1
BEGIN
INSERT 0 1
INSERT 0 1
INSERT 0 1
  xmin  | cmin | xmax | val
--------+------+------+-----
 322584 |    0 |    0 |   1
 322584 |    1 |    0 |   2
 322584 |    2 |    0 |   3

```

### [DELETE Using Cmin]

```sql
mvcc=# DELETE FROM mvcc_demo;
BEGIN WORK;
INSERT INTO mvcc_demo VALUES (1);
INSERT INTO mvcc_demo VALUES (2);
INSERT INTO mvcc_demo VALUES (3);
SELECT xmin, cmin, xmax, * FROM mvcc_demo;
DELETE 3
BEGIN
INSERT 0 1
INSERT 0 1
INSERT 0 1
  xmin  | cmin | xmax | val
--------+------+------+-----
 322586 |    0 |    0 |   1
 322586 |    1 |    0 |   2
 322586 |    2 |    0 |   3
mvcc=*# DECLARE c_mvcc_demo CURSOR FOR SELECT xmin, xmax, cmax, * FROM mvcc_demo;
DECLARE CURSOR
mvcc=*# DELETE FROM mvcc_demo;SELECT xmin, cmin, xmax, * FROM mvcc_demo;
DELETE 3
 xmin | cmin | xmax | val
------+------+------+-----


mvcc=*# FETCH ALL FROM c_mvcc_demo;
COMMIT WORK;
  xmin  |  xmax  | cmax | val
--------+--------+------+-----
 322586 | 322586 |    0 |   1
 322586 | 322586 |    1 |   2
 322586 | 322586 |    2 |   3


COMMIT
```

### [UPDATE Using Cmin]

```sql
mvcc=# DELETE FROM mvcc_demo;
BEGIN WORK;
INSERT INTO mvcc_demo VALUES (1);
INSERT INTO mvcc_demo VALUES (2);
INSERT INTO mvcc_demo VALUES (3);
SELECT xmin, cmin, xmax, * FROM mvcc_demo;
DELETE 0
BEGIN
INSERT 0 1
INSERT 0 1
INSERT 0 1
  xmin  | cmin | xmax | val
--------+------+------+-----
 322587 |    0 |    0 |   1
 322587 |    1 |    0 |   2
 322587 |    2 |    0 |   3

mvcc=*# DECLARE c_mvcc_demo CURSOR FOR SELECT xmin, xmax, cmax, * FROM mvcc_demo;
DECLARE CURSOR
mvcc=*# UPDATE mvcc_demo SET val = val * 10;
SELECT xmin, cmin, xmax, * FROM mvcc_demo;
UPDATE 3
  xmin  | cmin | xmax | val
--------+------+------+-----
 322587 |    3 |    0 |  10
 322587 |    3 |    0 |  20
 322587 |    3 |    0 |  30


mvcc=*# FETCH ALL FROM c_mvcc_demo;
COMMIT WORK;
  xmin  |  xmax  | cmax | val
--------+--------+------+-----
 322587 | 322587 |    0 |   1
 322587 | 322587 |    1 |   2
 322587 | 322587 |    2 |   3


COMMIT
```

### [Modifying Rows From Different Transactions]

cmin と cmax は内部的に 1 つのシステムカラムであるため、同じマルチステートメント内で、単純に行の作成と期限切れのステータスを記録することは不可能です。
行のステータスを記録することは不可能です。
トランザクションで作成され、期限切れになった行のステータスを単純に記録することはできません。そのため、特別なコンボコマンド ID が作成されます。

```sql
mvcc=# DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);
SELECT xmin, xmax, * FROM mvcc_demo;

DELETE 4
INSERT 0 1
  xmin  | xmax | val
--------+------+-----
 322592 |    0 |   1
mvcc=# BEGIN WORK;
INSERT INTO mvcc_demo VALUES (2);
INSERT INTO mvcc_demo VALUES (3);
INSERT INTO mvcc_demo VALUES (4);SELECT xmin, cmin, xmax, * FROM mvcc_demo;
UPDATE mvcc_demo SET val = val * 10;

BEGIN
INSERT 0 1
INSERT 0 1
INSERT 0 1
  xmin  | cmin | xmax | val
--------+------+------+-----
 322592 |    0 |    0 |   1
 322593 |    0 |    0 |   2
 322593 |    1 |    0 |   3
 322593 |    2 |    0 |   4
UPDATE 4
mvcc=# SELECT xmin, cmin, xmax, * FROM mvcc_demo;
  xmin  | cmin | xmax | val
--------+------+------+-----
 322593 |    3 |    0 |  10
 322593 |    3 |    0 |  20
 322593 |    3 |    0 |  30
 322593 |    3 |    0 |  40

            -- 別コネクション
            mvcc=# SELECT xmin, cmin, xmax, * FROM mvcc_demo;
            xmin  | cmin |  xmax  | val
            --------+------+--------+-----
            322592 |    3 | 322593 |   1

mvcc=*# COMMIT WORK;
COMMIT
```

### [UPDATE Using Combo Command Ids]

最後のクエリは/contrib/pageinspect を使用します。
構造体や、現在のスナップショットでは表示されていないものを含む、すべての保存された行を表示することができます。(ビット
0x0020 は内部的に HEAP_COMBOCID と呼ばれています)。

```sql
mvcc=# TRUNCATE mvcc_demo;
BEGIN WORK;
DELETE FROM mvcc_demo;
INSERT INTO mvcc_demo VALUES (1);
INSERT INTO mvcc_demo VALUES (2);
INSERT INTO mvcc_demo VALUES (3);
SELECT xmin, cmin, xmax, * FROM mvcc_demo;
TRUNCATE TABLE
BEGIN
DELETE 0
INSERT 0 1
INSERT 0 1
INSERT 0 1
  xmin  | cmin | xmax | val
--------+------+------+-----
 322596 |    3 |    0 |   1
 322596 |    4 |    0 |   2
 322596 |    5 |    0 |   3

mvcc=*# DECLARE c_mvcc_demo CURSOR FOR SELECT xmin, xmax, cmax, * FROM mvcc_demo;
DECLARE CURSOR
mvcc=*# UPDATE mvcc_demo SET val = val * 10;
SELECT xmin, cmin, xmax, * FROM mvcc_demo;
UPDATE 3
  xmin  | cmin | xmax | val
--------+------+------+-----
 322596 |    6 |    0 |  10
 322596 |    6 |    0 |  20
 322596 |    6 |    0 |  30
mvcc=*# FETCH ALL FROM c_mvcc_demo;
  xmin  |  xmax  | cmax | val
--------+--------+------+-----
 322596 | 322596 |    0 |   1
 322596 | 322596 |    1 |   2
 322596 | 322596 |    2 |   3

 mvcc=*# SELECT  t_xmin AS xmin, t_xmax::text::int8 AS xmax, t_field3::text::int8 AS cmin_cmax, (t_infomask::integer & X'0020'::integer)::bool AS is_combocid FROM heap_page_items(get_raw_page('mvcc_demo', 0)) ORDER BY 2 DESC, 3;
  xmin  |  xmax  | cmin_cmax | is_combocid
--------+--------+-----------+-------------
 322596 | 322596 |         0 | t
 322596 | 322596 |         1 | t
 322596 | 322596 |         2 | t
 322596 |      0 |         6 | f
 322596 |      0 |         6 | f
 322596 |      0 |         6 | f


mvcc=*# COMMIT WORK;
COMMIT
```

### [Cleanup of Deleted Rows]

通常のマルチユーザー使用では、クリーンアップが遅れることがある。
トランザクションがまだ期限切れの行を表示する必要があるからです。

```sql
mvcc=# TRUNCATE mvcc_demo;
TRUNCATE TABLE
mvcc=# INSERT INTO mvcc_demo SELECT 0 FROM generate_series(1, 220);
INSERT 0 220
mvcc=# SELECT (100 * (upper - lower) /         pagesize::float8)::integer AS free_pct FROM page_header(get_raw_page('mvcc_demo', 0));
 free_pct
----------
        3
mvcc=# INSERT INTO mvcc_demo VALUES (1);
SELECT * FROM mvcc_demo_page0 OFFSET 220;
INSERT 0 1
  ctid   |  case  |  xmin  | xmax | t_ctid
---------+--------+--------+------+---------
 (0,221) | Normal | 322600 |    0 | (0,221)

mvcc=# DELETE FROM mvcc_demo WHERE val > 0;
INSERT INTO mvcc_demo VALUES (2);
SELECT * FROM mvcc_demo_page0 OFFSET 220;
DELETE 1
INSERT 0 1
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Normal | 322600 | 322601 | (0,221)
 (0,222) | Normal | 322602 |      0 | (0,222)

mvcc=# DELETE FROM mvcc_demo WHERE val > 0;
INSERT INTO mvcc_demo VALUES (3);
SELECT * FROM mvcc_demo_page0 OFFSET 220;
DELETE 1
INSERT 0 1
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Dead   | (null) | (null) | (null)
 (0,222) | Normal | 322602 | 322603 | (0,222)
 (0,223) | Normal | 322604 |      0 | (0,223)

 mvcc=# SELECT * FROM mvcc_demo OFFSET 1000;SELECT * FROM mvcc_demo_page0 OFFSET 220;
 val
-----


  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Dead   | (null) | (null) | (null)
 (0,222) | Dead   | (null) | (null) | (null)
 (0,223) | Normal | 322604 |      0 | (0,223)

 mvcc=# SELECT pg_freespace('mvcc_demo');
 VACUUM mvcc_demo;
 SELECT * FROM mvcc_demo_page0 OFFSET 220;
 pg_freespace
--------------
 (0,192)


VACUUM
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Unused | (null) | (null) | (null)
 (0,222) | Unused | (null) | (null) | (null)
 (0,223) | Normal | 322604 |      0 | (0,223)

mvcc=# SELECT pg_freespace('mvcc_demo');
 pg_freespace
--------------
 (0,192)
```

### [Another Free Space Map Example]

```sql
mvcc=# TRUNCATE mvcc_demo;VACUUM mvcc_demo;SELECT pg_freespace('mvcc_demo');
TRUNCATE TABLE
VACUUM
 pg_freespace
--------------
mvcc=# INSERT INTO mvcc_demo VALUES (1);
VACUUM mvcc_demo;
SELECT pg_freespace('mvcc_demo');
INSERT INTO mvcc_demo VALUES (2);
VACUUM mvcc_demo;
SELECT pg_freespace('mvcc_demo');
INSERT 0 1
VACUUM
 pg_freespace
--------------
 (0,8128)


INSERT 0 1
VACUUM
 pg_freespace
--------------
 (0,8064)

mvcc=# DELETE FROM mvcc_demo WHERE val = 2;
VACUUM mvcc_demo;
SELECT pg_freespace('mvcc_demo');
DELETE 1
VACUUM
 pg_freespace
--------------
 (0,8128)

mvcc=# DELETE FROM mvcc_demo WHERE val = 1;
VACUUM mvcc_demo;
SELECT pg_freespace('mvcc_demo');
DELETE 1
VACUUM
 pg_freespace
--------------
mvcc=# SELECT pg_relation_size('mvcc_demo');
 pg_relation_size
------------------
                0
```

### [Cleanup of Old Updated Rows]

```sql
mvcc=# TRUNCATE mvcc_demo;
INSERT INTO mvcc_demo SELECT 0 FROM generate_series(1, 220);INSERT INTO mvcc_demo VALUES (1);
SELECT * FROM mvcc_demo_page0 OFFSET 220;
TRUNCATE TABLE
INSERT 0 220
INSERT 0 1
  ctid   |  case  |  xmin  | xmax | t_ctid
---------+--------+--------+------+---------
 (0,221) | Normal | 322613 |    0 | (0,221)

mvcc=# UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;SELECT * FROM mvcc_demo_page0 OFFSET 220;
UPDATE 1
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Normal | 322613 | 322615 | (0,222)
 (0,222) | Normal | 322615 |      0 | (0,222)

mvcc=# UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;SELECT * FROM mvcc_demo_page0 OFFSET 220;
UPDATE 1
  ctid   |      case       |  xmin  |  xmax  | t_ctid
---------+-----------------+--------+--------+---------
 (0,221) | Redirect to 222 | (null) | (null) | (null)
 (0,222) | Normal          | 322615 | 322616 | (0,223)
 (0,223) | Normal          | 322616 |      0 | (0,223)

mvcc=# UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;SELECT * FROM mvcc_demo_page0 OFFSET 220;
UPDATE 1
  ctid   |      case       |  xmin  |  xmax  | t_ctid
---------+-----------------+--------+--------+---------
 (0,221) | Redirect to 223 | (null) | (null) | (null)
 (0,222) | Normal          | 322617 |      0 | (0,222)
 (0,223) | Normal          | 322616 | 322617 | (0,222)


mvcc=# SELECT * FROM mvcc_demo OFFSET 1000;
 val
-----

mvcc=# SELECT * FROM mvcc_demo_page0 OFFSET 220;
  ctid   |      case       |  xmin  |  xmax  | t_ctid
---------+-----------------+--------+--------+---------
 (0,221) | Redirect to 222 | (null) | (null) | (null)
 (0,222) | Normal          | 322617 |      0 | (0,222)

```

### [VACUUM Does Not Remove the Redirect]

```sql

mvcc=# VACUUM mvcc_demo;
SELECT * FROM mvcc_demo_page0 OFFSET 220;
VACUUM
  ctid   |      case       |  xmin  |  xmax  | t_ctid
---------+-----------------+--------+--------+---------
 (0,221) | Redirect to 222 | (null) | (null) | (null)
 (0,222) | Normal          | 322617 |      0 | (0,222)
```

### [Cleanup Using Manual VACUUM]

```sql
mvcc=# TRUNCATE mvcc_demo;INSERT INTO mvcc_demo VALUES (1);INSERT INTO mvcc_demo VALUES (2);INSERT INTO mvcc_demo VALUES (3);SELECT  ctid, xmin, xmax FROM mvcc_demo_page0;
TRUNCATE TABLE
INSERT 0 1
INSERT 0 1
INSERT 0 1
 ctid  |  xmin  | xmax
-------+--------+------
 (0,1) | 322623 |    0
 (0,2) | 322624 |    0
 (0,3) | 322625 |    0
mvcc=# DELETE FROM mvcc_demo;SELECT  ctid, xmin, xmax FROM mvcc_demo_page0;
DELETE 0
 ctid  |  xmin  |  xmax
-------+--------+--------
 (0,1) | 322623 | 322626
 (0,2) | 322624 | 322626
 (0,3) | 322625 | 322626
mvcc=# VACUUM mvcc_demo;SELECT pg_relation_size('mvcc_demo');
VACUUM
 pg_relation_size
------------------
                0
```

### [The Indexed UPDATE Problem]

```sql
mvcc=# CREATE INDEX i_mvcc_demo_val on mvcc_demo (val);TRUNCATE mvcc_demo;INSERT INTO mvcc_demo SELECT 0 FROM generate_series(1, 220);INSERT INTO mvcc_demo VALUES (1);SELECT * FROM mvcc_demo_page0 OFFSET 220;
CREATE INDEX
TRUNCATE TABLE
INSERT 0 220
INSERT 0 1
  ctid   |  case  |  xmin  | xmax | t_ctid
---------+--------+--------+------+---------
 (0,221) | Normal | 322631 |    0 | (0,221)
mvcc=# UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;
SELECT * FROM mvcc_demo_page0 OFFSET 220;
UPDATE 1
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Normal | 322631 | 322632 | (0,222)
 (0,222) | Normal | 322632 |      0 | (0,222)
UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;


SELECT * FROM mvcc_demo_page0
OFFSET 220;

mvcc=# UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;
SELECT * FROM mvcc_demo_page0 OFFSET 220;
UPDATE 1
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Dead   | (null) | (null) | (null)
 (0,222) | Dead   | (null) | (null) | (null)
 (0,223) | Normal | 322633 | 322635 | (0,224)
 (0,224) | Normal | 322635 |      0 | (0,224)

mvcc=# UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;SELECT * FROM mvcc_demo_page0 OFFSET 220;
UPDATE 1
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Dead   | (null) | (null) | (null)
 (0,222) | Dead   | (null) | (null) | (null)
 (0,223) | Dead   | (null) | (null) | (null)
 (0,224) | Normal | 322635 | 322636 | (0,225)
 (0,225) | Normal | 322636 |      0 | (0,225)

mvcc=# SELECT * FROM mvcc_demo OFFSET 1000;
 val
-----


mvcc=# SELECT * FROM mvcc_demo_page0 OFFSET 220;
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Dead   | (null) | (null) | (null)
 (0,222) | Dead   | (null) | (null) | (null)
 (0,223) | Dead   | (null) | (null) | (null)
 (0,224) | Dead   | (null) | (null) | (null)
 (0,225) | Normal | 322636 |      0 | (0,225)

mvcc=# VACUUM mvcc_demo;
SELECT * FROM mvcc_demo_page0 OFFSET 220;
VACUUM
  ctid   |  case  |  xmin  |  xmax  | t_ctid
---------+--------+--------+--------+---------
 (0,221) | Unused | (null) | (null) | (null)
 (0,222) | Unused | (null) | (null) | (null)
 (0,223) | Unused | (null) | (null) | (null)
 (0,224) | Unused | (null) | (null) | (null)
 (0,225) | Normal | 322636 |      0 | (0,225)
```
