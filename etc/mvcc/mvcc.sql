-- Generated from mvcc.pdf at https://momjian.us/presentations
-- This is intended to be run by psql so backslash commands are processed.

-- setup
\pset footer off
\pset null (null)

CREATE TABLE mvcc_demo (val INTEGER);

DROP VIEW IF EXISTS mvcc_demo_page0;

CREATE EXTENSION pageinspect;

CREATE EXTENSION pg_freespacemap;

CREATE VIEW mvcc_demo_page0 AS
        SELECT  '(0,' || lp || ')' AS ctid,
                CASE lp_flags
                        WHEN 0 THEN 'Unused'
                        WHEN 1 THEN 'Normal'
                        WHEN 2 THEN 'Redirect to ' || lp_off
                        WHEN 3 THEN 'Dead'
                END,
                t_xmin::text::int8 AS xmin,
                t_xmax::text::int8 AS xmax, 
                t_ctid
        FROM heap_page_items(get_raw_page('mvcc_demo', 0))
        ORDER BY lp;

DELETE FROM mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

SELECT xmin, xmax, * FROM mvcc_demo;

DELETE FROM mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

SELECT xmin, xmax, * FROM mvcc_demo;

BEGIN WORK;

DELETE FROM mvcc_demo;

SELECT xmin, xmax, * FROM mvcc_demo;


SELECT txid_current();

COMMIT WORK;

DELETE FROM mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

SELECT xmin, xmax, * FROM mvcc_demo;

BEGIN WORK;

UPDATE mvcc_demo SET val = 2;

SELECT xmin, xmax, * FROM mvcc_demo;


COMMIT WORK;

DELETE FROM mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

BEGIN WORK;

DELETE FROM mvcc_demo;

ROLLBACK WORK;

SELECT xmin, xmax, * FROM mvcc_demo;

DELETE FROM mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

BEGIN WORK;

SELECT xmin, xmax, * FROM mvcc_demo;

SELECT xmin, xmax, * FROM mvcc_demo FOR UPDATE;

SELECT xmin, xmax, * FROM mvcc_demo;

COMMIT WORK;

DELETE FROM mvcc_demo;

BEGIN WORK;

INSERT INTO mvcc_demo VALUES (1);

INSERT INTO mvcc_demo VALUES (2);

INSERT INTO mvcc_demo VALUES (3);

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

COMMIT WORK;

DELETE FROM mvcc_demo;

BEGIN WORK;

INSERT INTO mvcc_demo VALUES (1);

INSERT INTO mvcc_demo VALUES (2);

INSERT INTO mvcc_demo VALUES (3);

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

DECLARE c_mvcc_demo CURSOR FOR
SELECT xmin, xmax, cmax, * FROM mvcc_demo;

DELETE FROM mvcc_demo;

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

FETCH ALL FROM c_mvcc_demo;

COMMIT WORK;

DELETE FROM mvcc_demo;

BEGIN WORK;

INSERT INTO mvcc_demo VALUES (1);

INSERT INTO mvcc_demo VALUES (2);

INSERT INTO mvcc_demo VALUES (3);

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

DECLARE c_mvcc_demo CURSOR FOR
SELECT xmin, xmax, cmax, * FROM mvcc_demo;

UPDATE mvcc_demo SET val = val * 10;

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

FETCH ALL FROM c_mvcc_demo;

COMMIT WORK;

DELETE FROM mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

SELECT xmin, xmax, * FROM mvcc_demo;

BEGIN WORK;

INSERT INTO mvcc_demo VALUES (2);

INSERT INTO mvcc_demo VALUES (3);

INSERT INTO mvcc_demo VALUES (4);

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

UPDATE mvcc_demo SET val = val * 10;

SELECT xmin, cmin, xmax, * FROM mvcc_demo;


COMMIT WORK;

-- use TRUNCATE to remove even invisible rows
TRUNCATE mvcc_demo;

BEGIN WORK;

DELETE FROM mvcc_demo;

DELETE FROM mvcc_demo;

DELETE FROM mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

INSERT INTO mvcc_demo VALUES (2);

INSERT INTO mvcc_demo VALUES (3);

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

DECLARE c_mvcc_demo CURSOR FOR 
SELECT xmin, xmax, cmax, * FROM mvcc_demo;

UPDATE mvcc_demo SET val = val * 10;

SELECT xmin, cmin, xmax, * FROM mvcc_demo;

FETCH ALL FROM c_mvcc_demo;

SELECT  t_xmin AS xmin, 
        t_xmax::text::int8 AS xmax, 
        t_field3::text::int8 AS cmin_cmax,
        (t_infomask::integer & X'0020'::integer)::bool AS 
is_combocid
FROM heap_page_items(get_raw_page('mvcc_demo', 0))
ORDER BY 2 DESC, 3;

COMMIT WORK;

TRUNCATE mvcc_demo;

-- force page to < 10% empty
INSERT INTO mvcc_demo SELECT 0 FROM generate_series(1, 220);

-- compute free space percentage
SELECT (100 * (upper - lower) / 
        pagesize::float8)::integer AS free_pct
FROM page_header(get_raw_page('mvcc_demo', 0));

INSERT INTO mvcc_demo VALUES (1);

SELECT * FROM mvcc_demo_page0
OFFSET 220;

DELETE FROM mvcc_demo WHERE val > 0;

INSERT INTO mvcc_demo VALUES (2);

SELECT * FROM mvcc_demo_page0
OFFSET 220;

DELETE FROM mvcc_demo WHERE val > 0;

INSERT INTO mvcc_demo VALUES (3);

SELECT * FROM mvcc_demo_page0
OFFSET 220;

-- force single-page cleanup via SELECT
SELECT * FROM mvcc_demo
OFFSET 1000;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

SELECT pg_freespace('mvcc_demo');

VACUUM mvcc_demo;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

SELECT pg_freespace('mvcc_demo');

TRUNCATE mvcc_demo;

VACUUM mvcc_demo;

SELECT pg_freespace('mvcc_demo');

INSERT INTO mvcc_demo VALUES (1);

VACUUM mvcc_demo;

SELECT pg_freespace('mvcc_demo');

INSERT INTO mvcc_demo VALUES (2);

VACUUM mvcc_demo;

SELECT pg_freespace('mvcc_demo');

DELETE FROM mvcc_demo WHERE val = 2;

VACUUM mvcc_demo;

SELECT pg_freespace('mvcc_demo');

DELETE FROM mvcc_demo WHERE val = 1;

VACUUM mvcc_demo;

SELECT pg_freespace('mvcc_demo');

SELECT pg_relation_size('mvcc_demo');

TRUNCATE mvcc_demo;

INSERT INTO mvcc_demo SELECT 0 FROM generate_series(1, 220);

INSERT INTO mvcc_demo VALUES (1);

SELECT * FROM mvcc_demo_page0
OFFSET 220;

UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

-- transaction now committed, HOT chain allows tid
-- to be marked as “Unused”
SELECT * FROM mvcc_demo
OFFSET 1000;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

VACUUM mvcc_demo;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

TRUNCATE mvcc_demo;

INSERT INTO mvcc_demo VALUES (1);

INSERT INTO mvcc_demo VALUES (2);

INSERT INTO mvcc_demo VALUES (3);

SELECT  ctid, xmin, xmax
FROM mvcc_demo_page0;

DELETE FROM mvcc_demo;

SELECT  ctid, xmin, xmax
FROM mvcc_demo_page0;

-- too small to trigger autovacuum
VACUUM mvcc_demo;

SELECT pg_relation_size('mvcc_demo');

CREATE INDEX i_mvcc_demo_val on mvcc_demo (val);

TRUNCATE mvcc_demo;

INSERT INTO mvcc_demo SELECT 0 FROM generate_series(1, 220);

INSERT INTO mvcc_demo VALUES (1);

SELECT * FROM mvcc_demo_page0
OFFSET 220;

UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

UPDATE mvcc_demo SET val = val + 1 WHERE val > 0;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

SELECT * FROM mvcc_demo
OFFSET 1000;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

VACUUM mvcc_demo;

SELECT * FROM mvcc_demo_page0
OFFSET 220;

