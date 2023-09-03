# Lock Manager

次のウェビナー動画で紹介されていたスクリプトを元にロックの動作確認を行います。

---

第 6 回～ 7 回 PostgreSQL のロックマネージャをアンロックする  
https://edbjapan.com/postgresql-technical-webinar-announcement/

スクリプトの提供元  
https://momjian.us/main/  
ウェビナーの本流  
https://momjian.us/main/writings/pgsql/locking.pdf

---

### [Setup]

```shell
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
psql -U postgres -p 5432 -d sample
sample=# \pset footer off
sample=# \pset null (null)
Null表示は"(null)"です。
```

### [What Is Our Process Identifier]

サーバー側で作られるコネクション毎のプロセスのうち、自分のものを取得する方法

```sql
sample=# SELECT pg_backend_pid();
 pg_backend_pid
----------------
           9404
```

### [What Is Our Virtual XID]

3 はバックエンド id。547 は仮想トランザクション id。

```sql
sample=# SELECT  virtualtransaction AS vxid, transactionid::text FROM  pg_locks WHERE   pid = pg_backend_pid() ORDER BY 1, 2 ;
 vxid  | transactionid
-------+---------------
 3/547 | (null)
 3/547 | (null)
```

### [What Is Our Backend Id?]

```
sample=# SELECT * FROM    pg_stat_get_backend_idset() AS t(id) WHERE   pg_stat_get_backend_pid(id) = pg_backend_pid();
 id
----
  3
```

### [The VXID Increments]

```sql
sample=# SELECT virtualtransaction AS vxid, transactionid::text FROM  pg_locks WHERE   pid = pg_backend_pid() ORDER BY 1, 2 LIMIT 1;
 vxid  | transactionid
-------+---------------
 3/549 | (null)
```

### [Getting a Real/External/Non-Virtual XID]

```sql
sample=# BEGIN WORK;
BEGIN
sample=*# SELECT  virtualtransaction AS vxid, transactionid::text FROM    pg_locks WHERE   pid = pg_backend_pid() ORDER BY 1, 2 LIMIT 1;
vxid  | transactionid
-------+---------------
3/556 | (null)
sample=*# ANALYZE pg_language;
ANALYZE
sample=*# SELECT  virtualtransaction AS vxid, transactionid::text FROM    pg_locks WHERE   pid = pg_backend_pid() ORDER BY 1, 2 LIMIT 1;
vxid  | transactionid
-------+---------------
3/556 | 322640
sample=*# SELECT txid_current();
txid_current
--------------
      322640


sample=*# COMMIT;
COMMIT
```

### [Requesting Your XID Assigns One]

```sql
sample=# BEGIN WORK;
BEGIN
sample=*# SELECT  virtualtransaction AS vxid, transactionid::text FROM    pg_locks WHERE   pid = pg_backend_pid() ORDER BY 1, 2 LIMIT 1;
 vxid  | transactionid
-------+---------------
 3/557 | (null)


sample=*# SELECT txid_current();
 txid_current
--------------
       322641


sample=*# SELECT  virtualtransaction AS vxid, transactionid::text FROM    pg_locks WHERE   pid = pg_backend_pid() ORDER BY 1, 2 LIMIT 1;
 vxid  | transactionid
-------+---------------
 3/557 | 322641


sample=*# COMMIT;
COMMIT
```

### [Setup: Create View lockview]

```sql
sample=# CREATE VIEW lockview AS
sample-# SELECT  pid, virtualtransaction AS vxid, locktype AS lock_type,
sample-#         mode AS lock_mode, granted,
sample-#         CASE
sample-#                 WHEN virtualxid IS NOT NULL AND transactionid
sample-# IS NOT NULL
sample-#                 THEN    virtualxid || ' ' || transactionid
sample-#                 WHEN virtualxid::text IS NOT NULL
sample-#                 THEN    virtualxid
sample-#                 ELSE    transactionid::text
sample-#         END AS xid_lock, relname,
sample-#         page, tuple, classid, objid, objsubid
sample-# FROM    pg_locks LEFT OUTER JOIN pg_class ON (pg_locks.relation
sample(# = pg_class.oid)
sample-# WHERE   -- do not show our view's locks
sample-#         pid != pg_backend_pid() AND
sample-#         virtualtransaction IS DISTINCT FROM virtualxid
sample-# ORDER BY 1, 2, 5 DESC, 6, 3, 4, 7;
CREATE VIEW
```

### [Create View lockview1]

```sql
sample=# CREATE VIEW lockview1 AS
sample-# SELECT  pid, vxid, lock_type, lock_mode,
sample-#         granted, xid_lock, relname
sample-# FROM    lockview
sample-# ORDER BY 1, 2, 5 DESC, 6, 3, 4, 7;
CREATE VIEW
```

### [Create View lockview2]

```sql
sample=# CREATE VIEW lockview2 AS
sample-# SELECT  pid, vxid, lock_type, page,
sample-#         tuple, classid, objid, objsubid
sample-# FROM    lockview
sample-# ORDER BY 1, 2, granted DESC, vxid, xid_lock::text, 3, 4, 5, 6, 7, 8;
CREATE VIEW
```

### [Create and Populate Table lockdemo]

```sql
sample=# CREATE TABLE lockdemo (col int);INSERT INTO lockdemo VALUES (1);
CREATE TABLE
INSERT 0 1
```

### [Explicit ACCESS SHARE Locking]

```sql
sample=# BEGIN WORK;
LOCK TABLE lockdemo IN ACCESS SHARE MODE;
BEGIN
LOCK TABLE
sample=*# \setenv PGDATABASE :DBNAME
sample=*# \! psql -U postgres -e -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
  pid  | vxid  | lock_type |    lock_mode    | granted | xid_lock | relname
-------+-------+-----------+-----------------+---------+----------+----------
 12552 | 3/564 | relation  | AccessShareLock | t       |          | lockdemo
(1 行)
sample=*# \! psql -U postgres -e -c "SELECT * FROM lockview2;"
ユーザー postgres のパスワード:
SELECT * FROM lockview2;
  pid  | vxid  | lock_type | page | tuple | classid | objid | objsubid
-------+-------+-----------+------+-------+---------+-------+----------
 12552 | 3/564 | relation  |      |       |         |       |
(1 行)
sample=*# COMMIT;
COMMIT
```

### [Implicit ACCESS SHARE Locking]

```sql
sample=# BEGIN WORK;
SELECT * FROM lockdemo;
BEGIN
 col
-----
   1
sample=*# \! psql -U postgres -e -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
  pid  | vxid  | lock_type |    lock_mode    | granted | xid_lock | relname
-------+-------+-----------+-----------------+---------+----------+----------
 12552 | 3/565 | relation  | AccessShareLock | t       |          | lockdemo
(1 行)
sample=*# COMMIT;
COMMIT
```

### [Multi-Table ACCESS SHARE Locking]

```sql
sample=# BEGIN WORK;
BEGIN
sample=*# SELECT  pg_class.oid FROM  pg_class JOIN pg_namespace ON (relnamespace = pg_namespace.oid) JOIN pg_attribute ON (pg_class.oid = pg_attribute.attrelid) LIMIT 1;
  oid
-------
 18083
sample=*# \! psql -U postgres -e -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
  pid  | vxid  | lock_type |    lock_mode    | granted | xid_lock |              relname
-------+-------+-----------+-----------------+---------+----------+-----------------------------------
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_attribute
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_attribute_relid_attnam_index
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_attribute_relid_attnum_index
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_class
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_class_oid_index
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_class_relname_nsp_index
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_class_tblspc_relfilenode_index
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_namespace
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_namespace_nspname_index
 12552 | 3/566 | relation  | AccessShareLock | t       |          | pg_namespace_oid_index
(10 行)
sample=*# COMMIT;
COMMIT
```

### [Explicit ROW SHARE Locking]

```sql
sample=# BEGIN WORK;LOCK TABLE lockdemo IN ROW SHARE MODE;
BEGIN
LOCK TABLE
sample=*# \! psql -U postgres -e -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
  pid  | vxid  | lock_type |  lock_mode   | granted | xid_lock | relname
-------+-------+-----------+--------------+---------+----------+----------
 12552 | 3/567 | relation  | RowShareLock | t       |          | lockdemo
(1 行)


sample=*# COMMIT;
COMMIT
```

### [Implicit ROW SHARE Locking]

```sql
sample=# BEGIN WORK;
SELECT * FROM lockdemo FOR SHARE;SELECT txid_current();
BEGIN
 col
-----
   1


 txid_current
--------------
       322647


sample=*# \! psql -U postgres -e -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
  pid  | vxid  |   lock_type   |   lock_mode   | granted | xid_lock | relname
-------+-------+---------------+---------------+---------+----------+----------
 12552 | 3/568 | transactionid | ExclusiveLock | t       | 322647   |
 12552 | 3/568 | relation      | RowShareLock  | t       |          | lockdemo
(2 行)
sample=*# COMMIT;
COMMIT
```

### [Explicit ROW EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;LOCK TABLE lockdemo IN ROW EXCLUSIVE MODE;
BEGIN
LOCK TABLE
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  | lock_type |    lock_mode     | granted | xid_lock | relname
------+-------+-----------+------------------+---------+----------+----------
 1292 | 3/572 | relation  | RowExclusiveLock | t       |          | lockdemo
```

### [Implicit ROW EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;
DELETE FROM lockdemo;
BEGIN
DELETE 1
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock | relname
------+-------+---------------+------------------+---------+----------+----------
 1292 | 3/576 | transactionid | ExclusiveLock    | t       | 322650   |
 1292 | 3/576 | relation      | RowExclusiveLock | t       |          | lockdemo
(2 行)


sample=*# COMMIT;
COMMIT
```

### [Explicit SHARE UPDATE EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;
BEGIN
sample=*# LOCK TABLE lockdemo IN SHARE UPDATE EXCLUSIVE MODE;
LOCK TABLE
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  | lock_type |        lock_mode         | granted | xid_lock | relname
------+-------+-----------+--------------------------+---------+----------+----------
 1292 | 3/577 | relation  | ShareUpdateExclusiveLock | t       |          | lockdemo
(1 行)


sample=*# commit;
COMMIT
```

### [Implicit SHARE UPDATE EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;ANALYZE lockdemo;
BEGIN
ANALYZE
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  | lock_type |        lock_mode         | granted | xid_lock | relname
------+-------+-----------+--------------------------+---------+----------+----------
 1292 | 3/581 | relation  | ShareUpdateExclusiveLock | t       |          | lockdemo
(1 行)


sample=*# ROLLBACK WORK;
ROLLBACK
```

### [Explicit SHARE Locking]

```sql
sample=# BEGIN WORK;
LOCK TABLE lockdemo IN SHARE MODE;
BEGIN
LOCK TABLE
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  | lock_type | lock_mode | granted | xid_lock | relname
------+-------+-----------+-----------+---------+----------+----------
 1292 | 3/582 | relation  | ShareLock | t       |          | lockdemo
(1 行)


sample=*# COMMIT;
COMMIT
```

### [Implicit SHARE Locking]

```sql
sample=# BEGIN WORK;
CREATE UNIQUE INDEX i_lockdemo on lockdemo(col);
BEGIN
CREATE INDEX
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |      lock_mode      | granted | xid_lock | relname
------+-------+---------------+---------------------+---------+----------+----------
 1292 | 3/583 | transactionid | ExclusiveLock       | t       | 322651   |
 1292 | 3/583 | relation      | AccessExclusiveLock | t       |          |
 1292 | 3/583 | relation      | ShareLock           | t       |          | lockdemo
(3 行)


sample=*# COMMIT;
COMMIT
```

### [Explicit SHARE ROW EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;LOCK TABLE lockdemo IN SHARE ROW EXCLUSIVE MODE;
BEGIN
LOCK TABLE
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  | lock_type |       lock_mode       | granted | xid_lock | relname
------+-------+-----------+-----------------------+---------+----------+----------
 1292 | 3/584 | relation  | ShareRowExclusiveLock | t       |          | lockdemo
(1 行)


sample=*# COMMIT;
COMMIT
```

### [Implicit SHARE ROW EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;
LOCK TABLE lockdemo IN SHARE ROW EXCLUSIVE MODE;
BEGIN
LOCK TABLE
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  | lock_type |       lock_mode       | granted | xid_lock | relname
------+-------+-----------+-----------------------+---------+----------+----------
 1292 | 3/585 | relation  | ShareRowExclusiveLock | t       |          | lockdemo
(1 行)


sample=*# COMMIT;
COMMIT
```

### [Explicit EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;
CREATE TRIGGER lockdemo_trigger BEFORE UPDATE ON lockdemo FOR EACH ROW EXECUTE FUNCTION suppress_redundant_updates_trigger();
BEGIN
CREATE TRIGGER
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |       lock_mode       | granted | xid_lock | relname
------+-------+---------------+-----------------------+---------+----------+----------
 1292 | 3/586 | transactionid | ExclusiveLock         | t       | 322652   |
 1292 | 3/586 | relation      | ShareRowExclusiveLock | t       |          | lockdemo
(2 行)


sample=*# ROLLBACK WORK;
ROLLBACK
```

### [Explicit ACCESS EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;LOCK TABLE lockdemo IN ACCESS EXCLUSIVE MODE;
BEGIN
LOCK TABLE
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |      lock_mode      | granted | xid_lock | relname
------+-------+---------------+---------------------+---------+----------+----------
 1292 | 3/587 | transactionid | ExclusiveLock       | t       | 322653   |
 1292 | 3/587 | relation      | AccessExclusiveLock | t       |          | lockdemo
(2 行)


sample=*# COMMIT;
COMMIT
```

### [Implicit ACCESS EXCLUSIVE Locking]

```sql
sample=# BEGIN WORK;
LUSTER lockdemo USING i_lockdemo;
BEGIN
CLUSTER
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |      lock_mode      | granted | xid_lock |  relname
------+-------+---------------+---------------------+---------+----------+------------
 1292 | 3/588 | transactionid | ExclusiveLock       | t       | 322654   |
 1292 | 3/588 | object        | AccessExclusiveLock | t       |          |
 1292 | 3/588 | object        | AccessExclusiveLock | t       |          |
 1292 | 3/588 | relation      | AccessExclusiveLock | t       |          | i_lockdemo
 1292 | 3/588 | relation      | AccessExclusiveLock | t       |          | lockdemo
 1292 | 3/588 | relation      | AccessExclusiveLock | t       |          |
 1292 | 3/588 | relation      | AccessShareLock     | t       |          | i_lockdemo
 1292 | 3/588 | relation      | ShareLock           | t       |          | lockdemo
(8 行)


sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview2;"
ユーザー postgres のパスワード:
SELECT * FROM lockview2;
 pid  | vxid  |   lock_type   | page | tuple | classid | objid | objsubid
------+-------+---------------+------+-------+---------+-------+----------
 1292 | 3/588 | transactionid |      |       |         |       |
 1292 | 3/588 | object        |      |       |    1247 | 18102 |        0
 1292 | 3/588 | object        |      |       |    1247 | 18103 |        0
 1292 | 3/588 | relation      |      |       |         |       |
 1292 | 3/588 | relation      |      |       |         |       |
 1292 | 3/588 | relation      |      |       |         |       |
 1292 | 3/588 | relation      |      |       |         |       |
 1292 | 3/588 | relation      |      |       |         |       |
(8 行)


sample=*# COMMIT;
COMMIT
```

## Example

### [Row Locks Are Not Visible in pg_locks]

```sql
sample=# DELETE FROM lockdemo;BEGIN WORK;
INSERT INTO lockdemo VALUES (1);
DELETE 0
BEGIN
INSERT 0 1
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock | relname
------+-------+---------------+------------------+---------+----------+----------
 1292 | 3/590 | transactionid | ExclusiveLock    | t       | 322655   |
 1292 | 3/590 | relation      | RowExclusiveLock | t       |          | lockdemo
(2 行)


sample=*# INSERT INTO lockdemo VALUES (2), (3);
INSERT 0 2
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock | relname
------+-------+---------------+------------------+---------+----------+----------
 1292 | 3/590 | transactionid | ExclusiveLock    | t       | 322655   |
 1292 | 3/590 | relation      | RowExclusiveLock | t       |          | lockdemo
(2 行)


sample=*# COMMIT;
COMMIT
```

### [Update Also Causes an Index Lock]

```sql
sample=# BEGIN WORK;UPDATE lockdemo SET col = 1 WHERE col = 1;
BEGIN
UPDATE 1
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
------+-------+---------------+------------------+---------+----------+------------
 1292 | 3/591 | transactionid | ExclusiveLock    | t       | 322656   |
 1292 | 3/591 | relation      | RowExclusiveLock | t       |          | i_lockdemo
 1292 | 3/591 | relation      | RowExclusiveLock | t       |          | lockdemo
(3 行)


sample=*# UPDATE lockdemo SET col = 2 WHERE col = 2;UPDATE lockdemo SET col = 3 WHERE col = 3;
UPDATE 1
UPDATE 1
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
------+-------+---------------+------------------+---------+----------+------------
 1292 | 3/591 | transactionid | ExclusiveLock    | t       | 322656   |
 1292 | 3/591 | relation      | RowExclusiveLock | t       |          | i_lockdemo
 1292 | 3/591 | relation      | RowExclusiveLock | t       |          | lockdemo
(3 行)


sample=*# COMMIT;
COMMIT
```

### [Delete of One Row Is Similar]

```sql
sample=# BEGIN WORK;DELETE FROM lockdemo WHERE col = 1;
BEGIN
DELETE 1
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
------+-------+---------------+------------------+---------+----------+------------
 1292 | 3/592 | transactionid | ExclusiveLock    | t       | 322657   |
 1292 | 3/592 | relation      | RowExclusiveLock | t       |          | i_lockdemo
 1292 | 3/592 | relation      | RowExclusiveLock | t       |          | lockdemo
(3 行)


sample=*# DELETE FROM lockdemo;
DELETE 2
sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
------+-------+---------------+------------------+---------+----------+------------
 1292 | 3/592 | transactionid | ExclusiveLock    | t       | 322657   |
 1292 | 3/592 | relation      | RowExclusiveLock | t       |          | i_lockdemo
 1292 | 3/592 | relation      | RowExclusiveLock | t       |          | lockdemo
(3 行)


sample=*# ROLLBACK WORK;
ROLLBACK
```

### [Explicit Row Locks Are Similar]

```sql
sample=# BEGIN WORK;
SELECT * FROM lockdemo WHERE col = 1 FOR UPDATE;
BEGIN
 col
-----
   1
(1 行)


sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |   lock_mode   | granted | xid_lock |  relname
------+-------+---------------+---------------+---------+----------+------------
 1292 | 3/593 | transactionid | ExclusiveLock | t       | 322658   |
 1292 | 3/593 | relation      | RowShareLock  | t       |          | i_lockdemo
 1292 | 3/593 | relation      | RowShareLock  | t       |          | lockdemo
(3 行)


sample=*# SELECT * FROM lockdemo FOR UPDATE;
 col
-----
   1
   2
   3
(3 行)


sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |   lock_mode   | granted | xid_lock |  relname
------+-------+---------------+---------------+---------+----------+------------
 1292 | 3/593 | transactionid | ExclusiveLock | t       | 322658   |
 1292 | 3/593 | relation      | RowShareLock  | t       |          | i_lockdemo
 1292 | 3/593 | relation      | RowShareLock  | t       |          | lockdemo
(3 行)


sample=*# COMMIT;
COMMIT
```

### [Explicit Shared Row Locks Are Similar]

```sql
sample=# BEGIN WORK;
SELECT * FROM lockdemo WHERE col = 1 FOR SHARE;
BEGIN
 col
-----
   1
(1 行)


sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |   lock_mode   | granted | xid_lock |  relname
------+-------+---------------+---------------+---------+----------+------------
 1292 | 3/594 | transactionid | ExclusiveLock | t       | 322659   |
 1292 | 3/594 | relation      | RowShareLock  | t       |          | i_lockdemo
 1292 | 3/594 | relation      | RowShareLock  | t       |          | lockdemo
(3 行)


sample=*# SELECT * FROM lockdemo FOR SHARE;
 col
-----
   1
   2
   3
(3 行)


sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |   lock_mode   | granted | xid_lock |  relname
------+-------+---------------+---------------+---------+----------+------------
 1292 | 3/594 | transactionid | ExclusiveLock | t       | 322659   |
 1292 | 3/594 | relation      | RowShareLock  | t       |          | i_lockdemo
 1292 | 3/594 | relation      | RowShareLock  | t       |          | lockdemo
(3 行)


sample=*# COMMIT;
COMMIT
```

### [Restore Table Lockdemo]

```sql
sample=# DELETE FROM lockdemo;INSERT INTO lockdemo VALUES (1);
DELETE 3
INSERT 0 1
sample=# BEGIN WORK;SELECT ctid, xmin, * FROM lockdemo;
BEGIN
 ctid  |  xmin  | col
-------+--------+-----
 (0,7) | 322661 |   1
(1 行)


sample=*# SELECT pg_backend_pid();SELECT txid_current();
 pg_backend_pid
----------------
           1292
(1 行)


 txid_current
--------------
       322662
(1 行)


sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode    | granted | xid_lock |  relname
------+-------+---------------+-----------------+---------+----------+------------
 1292 | 3/597 | transactionid | ExclusiveLock   | t       | 322662   |
 1292 | 3/597 | relation      | AccessShareLock | t       |          | i_lockdemo
 1292 | 3/597 | relation      | AccessShareLock | t       |          | lockdemo
(3 行)


sample=*# \! psql -U postgres -e -d sample -c "UPDATE lockdemo SET col = 2; SELECT pg_sleep(0.200)"
ユーザー postgres のパスワード:
UPDATE lockdemo SET col = 2; SELECT pg_sleep(0.200)
UPDATE 1
 pg_sleep
----------

(1 行)


sample=*# \! psql -U postgres -e -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |    lock_mode    | granted | xid_lock |  relname
------+-------+---------------+-----------------+---------+----------+------------
 1292 | 3/597 | transactionid | ExclusiveLock   | t       | 322662   |
 1292 | 3/597 | relation      | AccessShareLock | t       |          | i_lockdemo
 1292 | 3/597 | relation      | AccessShareLock | t       |          | lockdemo
(3 行)
```

### [Two Concurrent Updates Show Locking]

```sql
sample=*# BEGIN WORK;SELECT ctid, xmin, * FROM lockdemo;UPDATE lockdemo SET col = 2;
SELECT ctid, xmin, * FROM lockdemo;
SELECT pg_backend_pid();
SELECT txid_current();
WARNING:  すでにトランザクションが実行中です
BEGIN
 ctid  |  xmin  | col
-------+--------+-----
 (0,9) | 322662 |   1
(1 行)


UPDATE 1
  ctid  |  xmin  | col
--------+--------+-----
 (0,10) | 322662 |   2
(1 行)


 pg_backend_pid
----------------
           1292
(1 行)


 txid_current
--------------
       322662
(1 行)


sample=*# \! psql -U postgres -e -d sample -c "BEGIN WORK;UPDATE lockdemo SET col = 3;SELECT pg_sleep(0,200); COMMIT;"
ユーザー postgres のパスワード:
BEGIN WORK;UPDATE lockdemo SET col = 3;SELECT pg_sleep(0,200); COMMIT;

                sample-# \! psql -U postgres -d sample -e -c "SELECT * FROM lockview1;"
                ユーザー postgres のパスワード:
                SELECT * FROM lockview1;
                pid  |  vxid  |   lock_type   |      lock_mode      | granted | xid_lock |  relname
                -------+--------+---------------+---------------------+---------+----------+------------
                1292 | 3/597  | transactionid | ExclusiveLock       | t       | 322662   |
                1292 | 3/597  | relation      | AccessShareLock     | t       |          | i_lockdemo
                1292 | 3/597  | relation      | AccessShareLock     | t       |          | lockdemo
                1292 | 3/597  | relation      | RowExclusiveLock    | t       |          | i_lockdemo
                1292 | 3/597  | relation      | RowExclusiveLock    | t       |          | lockdemo
                15212 | 4/1133 | transactionid | ExclusiveLock       | t       | 322664   |
                15212 | 4/1133 | relation      | RowExclusiveLock    | t       |          | i_lockdemo
                15212 | 4/1133 | relation      | RowExclusiveLock    | t       |          | lockdemo
                15212 | 4/1133 | tuple         | AccessExclusiveLock | t       |          | lockdemo
                15212 | 4/1133 | transactionid | ShareLock           | f       | 322662   |
                (10 行)

                sample-# \! psql -U postgres -d sample -e -c "SELECT * FROM lockview2;"
                ユーザー postgres のパスワード:
                SELECT * FROM lockview2;
                pid  |  vxid  |   lock_type   | page | tuple | classid | objid | objsubid
                -------+--------+---------------+------+-------+---------+-------+----------
                1292 | 3/597  | transactionid |      |       |         |       |
                1292 | 3/597  | relation      |      |       |         |       |
                1292 | 3/597  | relation      |      |       |         |       |
                1292 | 3/597  | relation      |      |       |         |       |
                1292 | 3/597  | relation      |      |       |         |       |
                15212 | 4/1133 | transactionid |      |       |         |       |
                15212 | 4/1133 | relation      |      |       |         |       |
                15212 | 4/1133 | relation      |      |       |         |       |
                15212 | 4/1133 | tuple         |    0 |     8 |         |       |
                15212 | 4/1133 | transactionid |      |       |         |       |
                (10 行)
```

### [Three Concurrent Updates Show Locking]

```sql
CREATE VIEW lockinfo_hierarchy AS
        WITH RECURSIVE lockinfo1 AS (
                SELECT pid, vxid, granted, xid_lock, lock_type, relname, page, tuple
                FROM lockview
                WHERE xid_lock IS NOT NULL AND
                      relname IS NULL AND
                      granted
                UNION ALL
                SELECT lockview.pid, lockview.vxid,lockview.granted, lockview.xid_lock,lockview.lock_type, lockview.relname,
lockview.page, lockview.tuple
                FROM lockinfo1 JOIN lockview ON (lockinfo1.xid_lock = lockview.xid_lock)
                WHERE lockview.xid_lock IS NOT NULL AND
                      lockview.relname IS NULL AND
                      NOT lockview.granted AND
                      lockinfo1.granted),
        lockinfo2 AS (
                SELECT pid, vxid, granted, xid_lock, lock_type, relname, page, tuple
                FROM lockview
                WHERE lock_type = 'tuple' AND
                      granted
                UNION ALL
                SELECT lockview.pid, lockview.vxid, lockview.granted, lockview.xid_lock,lockview.lock_type, lockview.relname,
lockview.page, lockview.tuple
                FROM lockinfo2 JOIN lockview ON (
                        lockinfo2.lock_type = lockview.lock_type AND
                        lockinfo2.relname = lockview.relname AND
                        lockinfo2.page = lockview.page AND
                        lockinfo2.tuple = lockview.tuple)
                WHERE lockview.lock_type = 'tuple' AND
                      NOT lockview.granted AND
                      lockinfo2.granted
        )
        SELECT * FROM lockinfo1
        UNION ALL
        SELECT * FROM lockinfo2;
```

```sql
sample=# BEGIN WORK;SELECT ctid, xmin, * FROM lockdemo;UPDATE lockdemo SET col = 4;
BEGIN
 ctid  |  xmin  | col
-------+--------+-----
 (0,8) | 322663 |   2


UPDATE 1
sample=*# SELECT ctid, xmin, * FROM lockdemo;
  ctid  |  xmin  | col
--------+--------+-----
 (0,11) | 322666 |   4


sample=*# SELECT pg_backend_pid();
 pg_backend_pid
----------------
           6972


sample=*# SELECT txid_current();
 txid_current
--------------
       322666


sample=*# \! psql -U postgres -d sample -e -c "BEGIN WORK; UPDATE lockdemo SET col = 5; SELECT pg_sleep(0.200); COMMIT;"
ユーザー postgres のパスワード:
BEGIN WORK; UPDATE lockdemo SET col = 5; SELECT pg_sleep(0.200); COMMIT;

  sample=#  \! psql -U postgres -d sample -e -c "BEGIN WORK; UPDATE lockdemo SET col = 6; SELECT pg_sleep(0.200); COMMIT;"
  ユーザー postgres のパスワード:
  BEGIN WORK; UPDATE lockdemo SET col = 6; SELECT pg_sleep(0.200); COMMIT;

    sample=#  \! psql -U postgres -d sample -e -c "BEGIN WORK; UPDATE lockdemo SET col = 7; SELECT pg_sleep(0.200); COMMIT;"
    ユーザー postgres のパスワード:
    BEGIN WORK; UPDATE lockdemo SET col = 7; SELECT pg_sleep(0.200); COMMIT;

      sample=#  \! psql -U postgres -d sample -e -c "BEGIN WORK; UPDATE lockdemo SET col = 7; SELECT pg_sleep(0.200); COMMIT;"
      ユーザー postgres のパスワード:
      BEGIN WORK; UPDATE lockdemo SET col = 7; SELECT pg_sleep(0.200); COMMIT;

        sample=# \! psql -d sample -U postgres -e -c "SELECT * FROM lockview1;"
        ユーザー postgres のパスワード:
        SELECT * FROM lockview1;
          pid  | vxid  |   lock_type   |      lock_mode      | granted | xid_lock |  relname
        -------+-------+---------------+---------------------+---------+----------+------------
          5368 | 6/5   | transactionid | ExclusiveLock       | t       | 322668   |
          5368 | 6/5   | relation      | RowExclusiveLock    | t       |          | i_lockdemo
          5368 | 6/5   | relation      | RowExclusiveLock    | t       |          | lockdemo
          5368 | 6/5   | tuple         | AccessExclusiveLock | f       |          | lockdemo
          6972 | 3/100 | transactionid | ExclusiveLock       | t       | 322666   |
          6972 | 3/100 | relation      | AccessShareLock     | t       |          | i_lockdemo
          6972 | 3/100 | relation      | AccessShareLock     | t       |          | lockdemo
          6972 | 3/100 | relation      | RowExclusiveLock    | t       |          | i_lockdemo
          6972 | 3/100 | relation      | RowExclusiveLock    | t       |          | lockdemo
          9412 | 8/5   | transactionid | ExclusiveLock       | t       | 322669   |
          9412 | 8/5   | relation      | RowExclusiveLock    | t       |          | i_lockdemo
          9412 | 8/5   | relation      | RowExclusiveLock    | t       |          | lockdemo
          9412 | 8/5   | tuple         | AccessExclusiveLock | f       |          | lockdemo
        15228 | 4/95  | transactionid | ExclusiveLock       | t       | 322667   |
        15228 | 4/95  | relation      | RowExclusiveLock    | t       |          | i_lockdemo
        15228 | 4/95  | relation      | RowExclusiveLock    | t       |          | lockdemo
        15228 | 4/95  | tuple         | AccessExclusiveLock | t       |          | lockdemo
        15228 | 4/95  | transactionid | ShareLock           | f       | 322666   |
        (18 行)


        sample=# \! psql -d sample -U postgres -e -c "SELECT * FROM lockview2;"
        ユーザー postgres のパスワード:
        SELECT * FROM lockview2;
          pid  | vxid  |   lock_type   | page | tuple | classid | objid | objsubid
        -------+-------+---------------+------+-------+---------+-------+----------
          5368 | 6/5   | transactionid |      |       |         |       |
          5368 | 6/5   | relation      |      |       |         |       |
          5368 | 6/5   | relation      |      |       |         |       |
          5368 | 6/5   | tuple         |    0 |     8 |         |       |
          6972 | 3/100 | transactionid |      |       |         |       |
          6972 | 3/100 | relation      |      |       |         |       |
          6972 | 3/100 | relation      |      |       |         |       |
          6972 | 3/100 | relation      |      |       |         |       |
          6972 | 3/100 | relation      |      |       |         |       |
          9412 | 8/5   | transactionid |      |       |         |       |
          9412 | 8/5   | relation      |      |       |         |       |
          9412 | 8/5   | relation      |      |       |         |       |
          9412 | 8/5   | tuple         |    0 |     8 |         |       |
        15228 | 4/95  | transactionid |      |       |         |       |
        15228 | 4/95  | relation      |      |       |         |       |
        15228 | 4/95  | relation      |      |       |         |       |
        15228 | 4/95  | tuple         |    0 |     8 |         |       |
        15228 | 4/95  | transactionid |      |       |         |       |
        (18 行)


        sample=# \! psql -d sample -U postgres -e -c "SELECT * FROM lockinfo_hierarchy;"
        ユーザー postgres のパスワード:
        SELECT * FROM lockinfo_hierarchy;
          pid  | vxid  | granted | xid_lock |   lock_type   | relname  | page | tuple
        -------+-------+---------+----------+---------------+----------+------+-------
          5368 | 6/5   | t       | 322668   | transactionid |          |      |
          6972 | 3/100 | t       | 322666   | transactionid |          |      |
          9412 | 8/5   | t       | 322669   | transactionid |          |      |
        15228 | 4/95  | t       | 322667   | transactionid |          |      |
        15228 | 4/95  | f       | 322666   | transactionid |          |      |
        15228 | 4/95  | t       |          | tuple         | lockdemo |    0 |     8
          5368 | 6/5   | f       |          | tuple         | lockdemo |    0 |     8
          9412 | 8/5   | f       |          | tuple         | lockdemo |    0 |     8
        (8 行)
```

### [Deadlocks]

```sql
sample=# DELETE FROM lockdemo;
INSERT INTO lockdemo VALUES (50), (80);
DELETE 1
INSERT 0 2
sample=# BEGIN WORK;
UPDATE lockdemo SET col = 50 WHERE col = 50;SELECT pg_backend_pid();
BEGIN
UPDATE 1
 pg_backend_pid
----------------
           6972
sample=# SELECT txid_current();
 txid_current
--------------
       322673

        sample=# BEGIN WORK; UPDATE lockdemo SET col = 81 WHERE col = 80; UPDATE lockdemo SET col = 51 WHERE col = 50; COMMIT;SELECT pg_sleep(0.200);
        BEGIN
        UPDATE 1
        UPDATE 1
        COMMIT
        pg_sleep
        ----------

        (1 行)
sample=*# \! psql -e -U postgres -d sample -c "SELECT * FROM lockview1;"
ユーザー postgres のパスワード:
SELECT * FROM lockview1;
 pid  | vxid  |   lock_type   |      lock_mode      | granted | xid_lock |  relname
------+-------+---------------+---------------------+---------+----------+------------
 6972 | 3/103 | transactionid | ExclusiveLock       | t       | 322673   |
 6972 | 3/103 | relation      | RowExclusiveLock    | t       |          | i_lockdemo
 6972 | 3/103 | relation      | RowExclusiveLock    | t       |          | lockdemo
 8396 | 4/147 | transactionid | ExclusiveLock       | t       | 322675   |
 8396 | 4/147 | relation      | RowExclusiveLock    | t       |          | i_lockdemo
 8396 | 4/147 | relation      | RowExclusiveLock    | t       |          | lockdemo
 8396 | 4/147 | tuple         | AccessExclusiveLock | t       |          | lockdemo
 8396 | 4/147 | transactionid | ShareLock           | f       | 322673   |
(8 行)


sample=*# \! psql -e -U postgres -d sample -c "SELECT * FROM lockview2;"
ユーザー postgres のパスワード:
SELECT * FROM lockview2;
 pid  | vxid  |   lock_type   | page | tuple | classid | objid | objsubid
------+-------+---------------+------+-------+---------+-------+----------
 6972 | 3/103 | transactionid |      |       |         |       |
 6972 | 3/103 | relation      |      |       |         |       |
 6972 | 3/103 | relation      |      |       |         |       |
 8396 | 4/147 | transactionid |      |       |         |       |
 8396 | 4/147 | relation      |      |       |         |       |
 8396 | 4/147 | relation      |      |       |         |       |
 8396 | 4/147 | tuple         |    0 |    13 |         |       |
 8396 | 4/147 | transactionid |      |       |         |       |
(8 行)


sample=*# UPDATE lockdemo SET col = 80 WHERE col = 80;
ERROR:  デッドロックを検出しました
DETAIL:  プロセス 6972 は ShareLock を トランザクション 322675 で待機していましたが、プロセス 8396 でブロックされました
プロセス 8396 は ShareLock を トランザクション 322673 で待機していましたが、プロセス 6972 でブロックされました
HINT:  問い合わせの詳細はサーバーログを参照してください
CONTEXT:  リレーション"lockdemo"のタプル(0,14)の更新中
sample=!# COMMIT;
ROLLBACK
```

### [Three-Way Deadlocks]

```sql
sample=# DELETE FROM lockdemo;
INSERT INTO lockdemo VALUES (40), (60), (80);
BEGIN WORK;UPDATE lockdemo SET col = 40 WHERE col = 40;
SELECT pg_backend_pid();
SELECT txid_current();
DELETE 3
INSERT 0 3
BEGIN
UPDATE 1
 pg_backend_pid
----------------
           6972


 txid_current
--------------
       322683
      PS C:\Users\user> psql -U postgres -d sample -e -c "BEGIN WORK; UPDATE lockdemo SET col = 61 WHERE col = 60; UPDATE lockdemo SET col = 41 WHERE col = 40; COMMIT;"
      ユーザー postgres のパスワード:
      BEGIN WORK; UPDATE lockdemo SET col = 61 WHERE col = 60; UPDATE lockdemo SET col = 41 WHERE col = 40; COMMIT;
      BEGIN
      UPDATE 1
      UPDATE 1
      COMMIT

            PS C:\Users\user> psql -U postgres -d sample -e -c "BEGIN WORK; UPDATE lockdemo SET col = 81 WHERE col = 80; UPDATE lockdemo SET col = 61 WHERE col = 60; COMMIT;"
            ユーザー postgres のパスワード:
            BEGIN WORK; UPDATE lockdemo SET col = 81 WHERE col = 80; UPDATE lockdemo SET col = 61 WHERE col = 60; COMMIT;
            BEGIN
            UPDATE 1
            UPDATE 0
            COMMIT

sample=*# SELECT * FROM lockview1;
  pid  | vxid  |   lock_type   |      lock_mode      | granted | xid_lock |  relname
-------+-------+---------------+---------------------+---------+----------+------------
  6460 | 4/159 | transactionid | ExclusiveLock       | t       | 322684   | (null)
  6460 | 4/159 | relation      | RowExclusiveLock    | t       | (null)   | i_lockdemo
  6460 | 4/159 | relation      | RowExclusiveLock    | t       | (null)   | lockdemo
  6460 | 4/159 | tuple         | AccessExclusiveLock | t       | (null)   | lockdemo
  6460 | 4/159 | transactionid | ShareLock           | f       | 322683   | (null)
 10184 | 5/162 | transactionid | ExclusiveLock       | t       | 322685   | (null)
 10184 | 5/162 | relation      | RowExclusiveLock    | t       | (null)   | i_lockdemo
 10184 | 5/162 | relation      | RowExclusiveLock    | t       | (null)   | lockdemo
 10184 | 5/162 | tuple         | AccessExclusiveLock | t       | (null)   | lockdemo
 10184 | 5/162 | transactionid | ShareLock           | f       | 322684   | (null)


sample=*# SELECT * FROM lockview2;
  pid  | vxid  |   lock_type   |  page  | tuple  | classid | objid  | objsubid
-------+-------+---------------+--------+--------+---------+--------+----------
  6460 | 4/159 | transactionid | (null) | (null) |  (null) | (null) |   (null)
  6460 | 4/159 | relation      | (null) | (null) |  (null) | (null) |   (null)
  6460 | 4/159 | relation      | (null) | (null) |  (null) | (null) |   (null)
  6460 | 4/159 | tuple         |      0 |     26 |  (null) | (null) |   (null)
  6460 | 4/159 | transactionid | (null) | (null) |  (null) | (null) |   (null)
 10184 | 5/162 | transactionid | (null) | (null) |  (null) | (null) |   (null)
 10184 | 5/162 | relation      | (null) | (null) |  (null) | (null) |   (null)
 10184 | 5/162 | relation      | (null) | (null) |  (null) | (null) |   (null)
 10184 | 5/162 | tuple         |      0 |     27 |  (null) | (null) |   (null)
 10184 | 5/162 | transactionid | (null) | (null) |  (null) | (null) |   (null)


sample=*# UPDATE lockdemo SET col = 80 WHERE col = 80;
ERROR:  デッドロックを検出しました
DETAIL:  プロセス 6972 は ShareLock を トランザクション 322685 で待機していましたが、プロセス 10184 でブロックされました
プロセス 10184 は ShareLock を トランザクション 322684 で待機していましたが、プロセス 6460 でブロックされました
プロセス 6460 は ShareLock を トランザクション 322683 で待機していましたが、プロセス 6972 でブロックされました
HINT:  問い合わせの詳細はサーバーログを参照してください
CONTEXT:  リレーション"lockdemo"のタプル(0,28)の更新中
sample=!# COMMIT;
ROLLBACK
```

### [Serializable]

```sql
sample=# DELETE FROM lockdemo;
INSERT INTO lockdemo VALUES (1);
DELETE 3
INSERT 0 1
sample=# BEGIN WORK;SELECT * FROM lockdemo;
SELECT pg_backend_pid();SELECT txid_current();
BEGIN
 col
-----
   1


 pg_backend_pid
----------------
           6972


 txid_current
--------------
       322688

      PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview1;'
      ユーザー postgres のパスワード:
      SELECT * FROM lockview1;
      pid  | vxid  |   lock_type   |    lock_mode    | granted | xid_lock |  relname
      ------+-------+---------------+-----------------+---------+----------+------------
      6972 | 3/112 | transactionid | ExclusiveLock   | t       | 322688   |
      6972 | 3/112 | relation      | AccessShareLock | t       |          | i_lockdemo
      6972 | 3/112 | relation      | AccessShareLock | t       |          | lockdemo
      (3 行)
COMMIT;


sample=# BEGIN WORK;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM lockdemo;
SELECT pg_backend_pid();
SELECT txid_current();
BEGIN
SET
 col
-----
   1


 pg_backend_pid
----------------
           6972


 txid_current
--------------
       322689

      PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview1;'
      ユーザー postgres のパスワード:
      SELECT * FROM lockview1;
      pid  | vxid  |   lock_type   |    lock_mode    | granted | xid_lock |  relname
      ------+-------+---------------+-----------------+---------+----------+------------
      6972 | 3/113 | transactionid | ExclusiveLock   | t       | 322689   |
      6972 | 3/113 | relation      | AccessShareLock | t       |          | i_lockdemo
      6972 | 3/113 | relation      | AccessShareLock | t       |          | lockdemo
      6972 | 3/113 | relation      | SIReadLock      | t       |          | lockdemo
      (4 行)
sample=*# COMMIT;
COMMIT
```

### [Unique Insert Locking]

```sql
sample=# \d lockdemo
               テーブル"public.lockdemo"
 列  | タイプ  | 照合順序 | Null 値を許容 | デフォルト
-----+---------+----------+---------------+------------
 col | integer |          |               |
インデックス:
    "i_lockdemo" UNIQUE, btree (col) CLUSTER


sample=# BEGIN WORK;
INSERT INTO lockdemo VALUES (2);
SELECT pg_backend_pid();SELECT txid_current();
BEGIN
INSERT 0 1
 pg_backend_pid
----------------
           6972


 txid_current
--------------
       322690

      PS C:\Users\user> psql -e -d sample -U postgres -c "INSERT INTO lockdemo VALUES (2);"
      ユーザー postgres のパスワード:
      INSERT INTO lockdemo VALUES (2);

            PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview1;'
            ユーザー postgres のパスワード:
            SELECT * FROM lockview1;
              pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
            -------+-------+---------------+------------------+---------+----------+------------
              6972 | 3/123 | transactionid | ExclusiveLock    | t       | 322690   |
              6972 | 3/123 | relation      | RowExclusiveLock | t       |          | lockdemo
            10752 | 4/304 | transactionid | ExclusiveLock    | t       | 322691   |
            10752 | 4/304 | relation      | RowExclusiveLock | t       |          | i_lockdemo
            10752 | 4/304 | relation      | RowExclusiveLock | t       |          | lockdemo
            10752 | 4/304 | transactionid | ShareLock        | f       | 322690   |
            (6 行)

sample=*# ROLLBACK WORK;
ROLLBACK
```

### [Subtransactions]

```sql
sample=# BEGIN WORK;UPDATE lockdemo SET col = 1;
BEGIN
UPDATE 1


      PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview1;'
      ユーザー postgres のパスワード:
      SELECT * FROM lockview1;
        pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
      -------+-------+---------------+------------------+---------+----------+------------
      14836 | 3/143 | transactionid | ExclusiveLock    | t       | 322697   |
      14836 | 3/143 | relation      | RowExclusiveLock | t       |          | i_lockdemo
      14836 | 3/143 | relation      | RowExclusiveLock | t       |          | lockdemo
      (3 行)

sample=*# SAVEPOINT lockdemo1;UPDATE lockdemo SET col = 2;
SAVEPOINT
UPDATE 1


      PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview1;'
      ユーザー postgres のパスワード:
      SELECT * FROM lockview1;
        pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
      -------+-------+---------------+------------------+---------+----------+------------
      14836 | 3/143 | transactionid | ExclusiveLock    | t       | 322697   |
      14836 | 3/143 | transactionid | ExclusiveLock    | t       | 322698   |
      14836 | 3/143 | relation      | RowExclusiveLock | t       |          | i_lockdemo
      14836 | 3/143 | relation      | RowExclusiveLock | t       |          | lockdemo
      (4 行)

sample=*# ROLLBACK WORK TO SAVEPOINT lockdemo1;
UPDATE lockdemo SET col = 3;
ROLLBACK
UPDATE 1


      PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview1;'
      ユーザー postgres のパスワード:
      SELECT * FROM lockview1;
        pid  | vxid  |   lock_type   |    lock_mode     | granted | xid_lock |  relname
      -------+-------+---------------+------------------+---------+----------+------------
      14836 | 3/143 | transactionid | ExclusiveLock    | t       | 322697   |
      14836 | 3/143 | transactionid | ExclusiveLock    | t       | 322699   |
      14836 | 3/143 | relation      | RowExclusiveLock | t       |          | i_lockdemo
      14836 | 3/143 | relation      | RowExclusiveLock | t       |          | lockdemo
      (4 行)
sample=*# COMMIT;
COMMIT
```

### [Advisory Locks]

```sql
sample=# BEGIN WORK;
SELECT pg_advisory_lock(col) FROM lockdemo;
BEGIN
 pg_advisory_lock
------------------

(1 行)

      PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview1;'
      ユーザー postgres のパスワード:
      SELECT * FROM lockview1;
        pid  | vxid  | lock_type |    lock_mode    | granted | xid_lock |  relname
      -------+-------+-----------+-----------------+---------+----------+------------
      14836 | 3/144 | advisory  | ExclusiveLock   | t       |          |
      14836 | 3/144 | relation  | AccessShareLock | t       |          | i_lockdemo
      14836 | 3/144 | relation  | AccessShareLock | t       |          | lockdemo
      (3 行)


      PS C:\Users\user> psql -U postgres -d sample -e -c 'SELECT * FROM lockview2;'
      ユーザー postgres のパスワード:
      SELECT * FROM lockview2;
        pid  | vxid  | lock_type | page | tuple | classid | objid | objsubid
      -------+-------+-----------+------+-------+---------+-------+----------
      14836 | 3/144 | advisory  |      |       |       0 |     3 |        1
      14836 | 3/144 | relation  |      |       |         |       |
      14836 | 3/144 | relation  |      |       |         |       |
      (3 行)

sample=*# SELECT pg_advisory_unlock(col) FROM lockdemo;
 pg_advisory_unlock
--------------------
 t
(1 行)


sample=*# COMMIT;
COMMIT
```

### [Joining Pg_locks and Pg_stat_activity]

```sql
sample=# CREATE VIEW lock_stat_view AS SELECT  pg_stat_activity.pid AS pid, query, wait_event, vxid, lock_type,        lock_mode, granted, xid_lock FROM lockview JOIN pg_stat_activity ON (lockview.pid = pg_stat_activity.pid);
CREATE VIEW


sample=# BEGIN WORK;
UPDATE lockdemo SET col = 1;
SELECT pg_backend_pid();
SELECT txid_current();
BEGIN
UPDATE 1
 pg_backend_pid
----------------
          14836
(1 行)


 txid_current
--------------
       322701
(1 行)

      PS C:\Users\user> psql -U postgres -d sample -e -c "UPDATE lockdemo SET col = 2;"
      ユーザー postgres のパスワード:
      UPDATE lockdemo SET col = 2;

            PS C:\Users\user> psql -U postgres -d sample -e -c "UPDATE lockdemo SET col = 3;"
            ユーザー postgres のパスワード:
            UPDATE lockdemo SET col = 3;

                  PS C:\Users\user> psql -U postgres -d sample -e -c "SELECT * FROM lock_stat_view;"
                  ユーザー postgres のパスワード:
                  SELECT * FROM lock_stat_view;
                    pid  |            query             |  wait_event   | vxid  |   lock_type   |      lock_mode      | granted | xid_lock
                  -------+------------------------------+---------------+-------+---------------+---------------------+---------+----------
                    4032 | UPDATE lockdemo SET col = 3; | tuple         | 7/50  | transactionid | ExclusiveLock       | t       | 322703
                    4032 | UPDATE lockdemo SET col = 3; | tuple         | 7/50  | relation      | RowExclusiveLock    | t       |
                    4032 | UPDATE lockdemo SET col = 3; | tuple         | 7/50  | relation      | RowExclusiveLock    | t       |
                    4032 | UPDATE lockdemo SET col = 3; | tuple         | 7/50  | tuple         | ExclusiveLock       | f       |
                    9272 | UPDATE lockdemo SET col = 2; | transactionid | 5/437 | transactionid | ExclusiveLock       | t       | 322702
                    9272 | UPDATE lockdemo SET col = 2; | transactionid | 5/437 | relation      | RowExclusiveLock    | t       |
                    9272 | UPDATE lockdemo SET col = 2; | transactionid | 5/437 | relation      | RowExclusiveLock    | t       |
                    9272 | UPDATE lockdemo SET col = 2; | transactionid | 5/437 | tuple         | AccessExclusiveLock | t       |
                    9272 | UPDATE lockdemo SET col = 2; | transactionid | 5/437 | transactionid | ShareLock           | f       | 322701
                  14836 | SELECT txid_current();       | ClientRead    | 3/147 | transactionid | ExclusiveLock       | t       | 322701
                  14836 | SELECT txid_current();       | ClientRead    | 3/147 | relation      | RowExclusiveLock    | t       |
                  14836 | SELECT txid_current();       | ClientRead    | 3/147 | relation      | RowExclusiveLock    | t       |
                  (12 行)

sample=*# SELECT pg_blocking_pids(9272);
 pg_blocking_pids
------------------
 {14836}
(1 行)

sample=*# SELECT pg_blocking_pids(4032);
 pg_blocking_pids
------------------
 {9272}
(1 行)

sample=*# COMMIT;
COMMIT
```
