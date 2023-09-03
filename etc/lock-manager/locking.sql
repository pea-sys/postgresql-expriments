-- Generated from locking.pdf at https://momjian.us/presentations
-- This is intended to be run by psql so backslash commands are processed.

-- setup
\pset footer off
\pset null (null)

SELECT pg_backend_pid();

SELECT  virtualtransaction AS vxid, transactionid::text
FROM    pg_locks
WHERE   pid = pg_backend_pid()
ORDER BY 1, 2
LIMIT 1;

SELECT  *
FROM    pg_stat_get_backend_idset() AS t(id)
WHERE   pg_stat_get_backend_pid(id) = pg_backend_pid();

SELECT  virtualtransaction AS vxid, transactionid::text
FROM    pg_locks
WHERE   pid = pg_backend_pid()
ORDER BY 1, 2
LIMIT 1;

SELECT  virtualtransaction AS vxid, transactionid::text
FROM    pg_locks
WHERE   pid = pg_backend_pid()
ORDER BY 1, 2
LIMIT 1;

BEGIN WORK;

SELECT  virtualtransaction AS vxid, transactionid::text
FROM    pg_locks
WHERE   pid = pg_backend_pid()
ORDER BY 1, 2
LIMIT 1;

ANALYZE pg_language;

SELECT  virtualtransaction AS vxid, transactionid::text
FROM    pg_locks
WHERE   pid = pg_backend_pid()
ORDER BY 1, 2
LIMIT 1;

SELECT txid_current();

COMMIT;

BEGIN WORK;

SELECT  virtualtransaction AS vxid, transactionid::text
FROM    pg_locks
WHERE   pid = pg_backend_pid()
ORDER BY 1, 2
LIMIT 1;

-- this will assign a non-virtual xid if not already assigned
SELECT txid_current();

SELECT  virtualtransaction AS vxid, transactionid::text
FROM    pg_locks
WHERE   pid = pg_backend_pid()
ORDER BY 1, 2
LIMIT 1;

COMMIT;

-- cannot be a temporary view because other sessions must see 
CREATE VIEW lockview AS
SELECT  pid, virtualtransaction AS vxid, locktype AS lock_type, 
        mode AS lock_mode, granted,
        CASE
                WHEN virtualxid IS NOT NULL AND transactionid 
IS NOT NULL
                THEN    virtualxid || ' ' || transactionid
                WHEN virtualxid::text IS NOT NULL
                THEN    virtualxid
                ELSE    transactionid::text
        END AS xid_lock, relname,
        page, tuple, classid, objid, objsubid
FROM    pg_locks LEFT OUTER JOIN pg_class ON (pg_locks.relation 
= pg_class.oid)
WHERE   -- do not show our view's locks
        pid != pg_backend_pid() AND
        -- no need to show self-vxid locks
        virtualtransaction IS DISTINCT FROM virtualxid
-- granted is ordered earlier
ORDER BY 1, 2, 5 DESC, 6, 3, 4, 7;

CREATE VIEW lockview1 AS
SELECT  pid, vxid, lock_type, lock_mode, 
        granted, xid_lock, relname
FROM    lockview
-- granted is ordered earlier
ORDER BY 1, 2, 5 DESC, 6, 3, 4, 7;

CREATE VIEW lockview2 AS
SELECT  pid, vxid, lock_type, page,
        tuple, classid, objid, objsubid
FROM    lockview
-- granted is first
-- add non-display columns to match  ordering of lockview
ORDER BY 1, 2, granted DESC, vxid, xid_lock::text, 3, 4, 5, 6, 
7, 8;

CREATE TABLE lockdemo (col int);

INSERT INTO lockdemo VALUES (1);

BEGIN WORK;

LOCK TABLE lockdemo IN ACCESS SHARE MODE;

-- force future psql commands to use the current database
\setenv PGDATABASE :DBNAME
\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockview2;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

SELECT * FROM lockdemo;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

SELECT  pg_class.oid 
FROM    pg_class JOIN pg_namespace ON (relnamespace = 
pg_namespace.oid)
        JOIN pg_attribute ON (pg_class.oid = 
pg_attribute.attrelid)
LIMIT 1;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

LOCK TABLE lockdemo IN ROW SHARE MODE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

SELECT * FROM lockdemo FOR SHARE;

SELECT txid_current();

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

LOCK TABLE lockdemo IN ROW EXCLUSIVE MODE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

DELETE FROM lockdemo;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

ROLLBACK WORK;

BEGIN WORK;

LOCK TABLE lockdemo IN SHARE UPDATE EXCLUSIVE MODE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

ANALYZE lockdemo;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

ROLLBACK WORK;

BEGIN WORK;

LOCK TABLE lockdemo IN SHARE MODE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

CREATE UNIQUE INDEX i_lockdemo on lockdemo(col);

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

LOCK TABLE lockdemo IN SHARE ROW EXCLUSIVE MODE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

CREATE TRIGGER lockdemo_trigger
BEFORE UPDATE ON lockdemo
FOR EACH ROW EXECUTE FUNCTION 
suppress_redundant_updates_trigger();

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

ROLLBACK WORK;

BEGIN WORK;

LOCK TABLE lockdemo IN EXCLUSIVE MODE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

LOCK TABLE lockdemo IN ACCESS EXCLUSIVE MODE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

CLUSTER lockdemo USING i_lockdemo;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockview2;' | sed 's/^/\t/g'

COMMIT;

DELETE FROM lockdemo;

BEGIN WORK;

INSERT INTO lockdemo VALUES (1);

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

INSERT INTO lockdemo VALUES (2), (3);

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

UPDATE lockdemo SET col = 1 WHERE col = 1;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

UPDATE lockdemo SET col = 2 WHERE col = 2;

UPDATE lockdemo SET col = 3 WHERE col = 3;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

DELETE FROM lockdemo WHERE col = 1;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

DELETE FROM lockdemo;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

ROLLBACK WORK;

BEGIN WORK;

SELECT * FROM lockdemo WHERE col = 1 FOR UPDATE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

SELECT * FROM lockdemo FOR UPDATE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

SELECT * FROM lockdemo WHERE col = 1 FOR SHARE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

SELECT * FROM lockdemo FOR SHARE;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

DELETE FROM lockdemo;

INSERT INTO lockdemo VALUES (1);

BEGIN WORK;

SELECT ctid, xmin, * FROM lockdemo;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

\! psql -e -c 'UPDATE lockdemo SET col = 2; SELECT pg_sleep(0.200); SELECT ctid, xmin, * FROM lockdemo;' | sed 's/^/\t/g' &
\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT WORK;

DELETE FROM lockdemo;

INSERT INTO lockdemo VALUES (1);

BEGIN WORK;

SELECT ctid, xmin, * FROM lockdemo;

UPDATE lockdemo SET col = 2;

SELECT ctid, xmin, * FROM lockdemo;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'BEGIN WORK; UPDATE lockdemo SET col = 3; SELECT pg_sleep(0.200); COMMIT;' | sed 's/^/\t/g' &
\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockview2;' | sed 's/^/\t/g'

COMMIT;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

CREATE VIEW lockinfo_hierarchy AS
        WITH RECURSIVE lockinfo1 AS (
                SELECT pid, vxid, granted, xid_lock, lock_type, 
relname, page, tuple
                FROM lockview
                WHERE xid_lock IS NOT NULL AND
                      relname IS NULL AND
                      granted
                UNION ALL
                SELECT lockview.pid, lockview.vxid, 
lockview.granted, lockview.xid_lock, 
                        lockview.lock_type, lockview.relname, 
lockview.page, lockview.tuple
                FROM lockinfo1 JOIN lockview ON 
(lockinfo1.xid_lock = lockview.xid_lock)
                WHERE lockview.xid_lock IS NOT NULL AND
                      lockview.relname IS NULL AND
                      NOT lockview.granted AND
                      lockinfo1.granted),
        lockinfo2 AS (
                SELECT pid, vxid, granted, xid_lock, lock_type, 
relname, page, tuple
                FROM lockview
                WHERE lock_type = 'tuple' AND
                      granted
                UNION ALL
                SELECT lockview.pid, lockview.vxid, 
lockview.granted, lockview.xid_lock,
                        lockview.lock_type, lockview.relname, 
lockview.page, lockview.tuple
                FROM lockinfo2 JOIN lockview ON (
                        lockinfo2.lock_type = 
lockview.lock_type AND
                        lockinfo2.relname = lockview.relname 
AND
                        lockinfo2.page = lockview.page AND
                        lockinfo2.tuple = lockview.tuple)
                WHERE lockview.lock_type = 'tuple' AND
                      NOT lockview.granted AND
                      lockinfo2.granted
        )
        SELECT * FROM lockinfo1
        UNION ALL
        SELECT * FROM lockinfo2;

BEGIN WORK;

SELECT ctid, xmin, * FROM lockdemo;

UPDATE lockdemo SET col = 4;

SELECT ctid, xmin, * FROM lockdemo;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'BEGIN WORK; UPDATE lockdemo SET col = 5; SELECT pg_sleep(0.200); COMMIT;' | sed 's/^/\t/g' &
\! psql -e -c 'BEGIN WORK; UPDATE lockdemo SET col = 6; SELECT pg_sleep(0.200); COMMIT;' | sed 's/^/\t/g' &
\! psql -e -c 'BEGIN WORK; UPDATE lockdemo SET col = 7; SELECT pg_sleep(0.200); COMMIT;' | sed 's/^/\t/g' &
\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockview2;' | sed 's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockinfo_hierarchy;' | sed   's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

DELETE FROM lockdemo;

INSERT INTO lockdemo VALUES (50), (80);

BEGIN WORK;

UPDATE lockdemo SET col = 50 WHERE col = 50;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'BEGIN WORK; UPDATE lockdemo SET col = 81 WHERE col = 80; UPDATE lockdemo SET col = 51 WHERE col = 50; COMMIT;' | sed 's/^/\t/g' &
SELECT pg_sleep(0.200);

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockview2;' | sed 's/^/\t/g'

-- show lockview while waiting for deadlock_timeout
\! psql -e -c 'SELECT pg_sleep(0.200); SELECT * FROM lockview1;' | sed 's/^/\t/g' &
\! psql -e -c 'SELECT pg_sleep(0.400); SELECT * FROM lockview2;' | sed 's/^/\t/g' &
-- the next line hangs waiting for deadlock timeout
UPDATE lockdemo SET col = 80 WHERE col = 80;




COMMIT; 

DELETE FROM lockdemo;

INSERT INTO lockdemo VALUES (40), (60), (80);

BEGIN WORK;

UPDATE lockdemo SET col = 40 WHERE col = 40;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'BEGIN WORK; UPDATE lockdemo SET col = 61 WHERE col = 60; UPDATE lockdemo SET col = 41 WHERE col = 40; COMMIT;' | sed 's/^/\t/g' &
\! psql -e -c 'BEGIN WORK; UPDATE lockdemo SET col = 81 WHERE col = 80; UPDATE lockdemo SET col = 61 WHERE col = 60; COMMIT;' | sed 's/^/\t/g' &
SELECT pg_sleep(0.200);

\! psql -e -c 'SELECT pg_sleep(0.200); SELECT * FROM lockview1;' | sed 's/^/\t/g' &
\! psql -e -c 'SELECT pg_sleep(0.400); SELECT * FROM lockview2;' | sed 's/^/\t/g' &
-- the next line hangs waiting for deadlock timeout
UPDATE lockdemo SET col = 80 WHERE col = 80;




COMMIT;

DELETE FROM lockdemo;

INSERT INTO lockdemo VALUES (1);

BEGIN WORK;

SELECT * FROM lockdemo;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT * FROM lockdemo;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

\d lockdemo
BEGIN WORK;

INSERT INTO lockdemo VALUES (2);

SELECT pg_backend_pid();

SELECT txid_current();

\! PGOPTIONS='-c statement_timeout=200' psql -e -c 'INSERT INTO lockdemo VALUES (2);' | sed 's/^/\t/g' &
\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

SELECT pg_sleep(0.400);

ROLLBACK WORK;

BEGIN WORK;

UPDATE lockdemo SET col = 1;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

SAVEPOINT lockdemo1;

UPDATE lockdemo SET col = 2;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

ROLLBACK WORK TO SAVEPOINT lockdemo1;

UPDATE lockdemo SET col = 3;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

COMMIT;

BEGIN WORK;

SELECT pg_advisory_lock(col) FROM lockdemo;

\! psql -e -c 'SELECT * FROM lockview1;' | sed 's/^/\t/g'

\! psql -e -c 'SELECT * FROM lockview2;' | sed 's/^/\t/g'

SELECT pg_advisory_unlock(col) FROM lockdemo;

COMMIT;

-- cannot be a temporary view because other sessions must see 
CREATE VIEW lock_stat_view AS
SELECT  pg_stat_activity.pid AS pid,
        query, wait_event, vxid, lock_type,
        lock_mode, granted, xid_lock
FROM    lockview JOIN pg_stat_activity ON (lockview.pid = 
pg_stat_activity.pid);

BEGIN WORK;

UPDATE lockdemo SET col = 1;

SELECT pg_backend_pid();

SELECT txid_current();

\! psql -e -c 'UPDATE lockdemo SET col = 2;' | sed 's/^/\t/g' &
\! psql -e -c 'UPDATE lockdemo SET col = 3;' | sed 's/^/\t/g' &
\! psql -e -c 'SELECT * FROM lock_stat_view;' | sed 's/^/\t/g'
SELECT pg_blocking_pids(11740);

SELECT pg_blocking_pids(11748);

COMMIT;

