-- Generated from beyond.pdf at https://momjian.us/presentations
-- This is intended to be run by psql so backslash commands are processed.

-- setup
\pset footer off
\pset null (null)

-- This disables EXPLAIN cost output
\set EXPLAIN 'EXPLAIN (COSTS OFF)'
:EXPLAIN SELECT 1;

:EXPLAIN VALUES (1), (2);

:EXPLAIN SELECT * FROM generate_series(1,4);

CREATE TABLE large (x) AS SELECT generate_series(1, 1000000);

ANALYZE large; 

CREATE INDEX i_large ON large (x);

ALTER TABLE large ADD COLUMN y INTEGER;

:EXPLAIN SELECT * FROM large ORDER BY x, y;

:EXPLAIN SELECT DISTINCT * FROM generate_series(1, 10) ORDER BY 
1;

-- not UNION ALL
:EXPLAIN SELECT 1 UNION SELECT 2;

:EXPLAIN SELECT 1 UNION ALL SELECT 2;

:EXPLAIN (VALUES (1), (2) ORDER BY 1)
UNION ALL
         (VALUES (3), (4) ORDER BY 1)
ORDER BY 1;

CREATE TABLE small (x) AS
SELECT generate_series(1, 1000);

ANALYZE small;

:EXPLAIN SELECT * FROM small EXCEPT SELECT * FROM small;

-- table has to be too large to hash
:EXPLAIN SELECT * FROM large INTERSECT SELECT * FROM large;

:EXPLAIN SELECT * FROM small s1, small s2 WHERE s1.x != s2.x;

-- needs duplicates and too small for a hash join
CREATE TABLE small_with_dups (x) AS
SELECT generate_series(1, 1000)
FROM generate_series(1, 10);

-- unique and too big for a hash join
CREATE TABLE medium (x) AS
SELECT generate_series(1, 100000);

-- index required for this memoize example
CREATE INDEX i_medium ON medium (x);

ANALYZE;

:EXPLAIN SELECT * FROM small_with_dups JOIN medium USING (x);

-- must be small enough not to trigger HashAggregate
-- removing WHERE and adding ORDER BY x does the same
:EXPLAIN SELECT x FROM large WHERE x < 0 GROUP BY x;

:EXPLAIN SELECT COUNT(*) FROM medium;

:EXPLAIN SELECT x, COUNT(*) FROM medium GROUP BY x ORDER BY x;

:EXPLAIN SELECT DISTINCT x FROM medium;

:EXPLAIN SELECT x FROM medium GROUP BY ROLLUP(x);

:EXPLAIN SELECT x, SUM(x) OVER ()
FROM generate_series(1, 10) AS f(x);

:EXPLAIN SELECT SUM(x) FROM large;

CREATE TABLE huge (x) AS SELECT generate_series(1, 100000000);

ANALYZE huge;

:EXPLAIN SELECT * FROM huge ORDER BY 1;

:EXPLAIN SELECT * FROM huge UNION ALL SELECT * FROM huge ORDER 
BY 1;

:EXPLAIN SELECT * FROM huge h1 JOIN huge h2 USING (x);

:EXPLAIN WITH source AS MATERIALIZED (
        SELECT 1
)
SELECT * FROM source;

:EXPLAIN WITH RECURSIVE source (counter) AS (
    SELECT 1
    UNION ALL
    SELECT counter + 1
    FROM source
    WHERE counter < 10
)
SELECT * FROM source;

:EXPLAIN SELECT generate_series(1,4);

:EXPLAIN SELECT * FROM small FOR UPDATE;

:EXPLAIN SELECT * FROM small TABLESAMPLE SYSTEM(50);

:EXPLAIN SELECT *
FROM XMLTABLE('/ROWS/ROW'
PASSING
$$
  <ROWS>
    <ROW id="1">
      <COUNTRY_ID>US</COUNTRY_ID>
    </ROW>
  </ROWS>
$$
COLUMNS id int PATH '@id',
_id FOR ORDINALITY);

CREATE EXTENSION postgres_fdw;

CREATE SERVER postgres_fdw_test
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host 'localhost', dbname 'fdw_test');

CREATE USER MAPPING FOR PUBLIC
SERVER postgres_fdw_test
OPTIONS (password '');

CREATE FOREIGN TABLE other_world (greeting TEXT)
SERVER postgres_fdw_test
OPTIONS (table_name 'world');

:EXPLAIN SELECT * FROM other_world;

:EXPLAIN SELECT * FROM small WHERE ctid = '(0,1)';

:EXPLAIN INSERT INTO small VALUES (0);

:EXPLAIN UPDATE small SET x = 1 WHERE x = 0;

:EXPLAIN DELETE FROM small;

-- You cannot run EXPLAIN on utility commands like TRUNCATE.
:EXPLAIN TRUNCATE small;


CREATE TABLE mergetest (x, y) AS VALUES (1, NULL), (3, NULL), 
(5, NULL);

:EXPLAIN MERGE INTO mergetest
USING (VALUES (1), (2), (3), (4), (5), (6)) m (x)
ON mergetest.x = m.x
WHEN NOT MATCHED THEN
     INSERT (x) VALUES (m.x)
WHEN MATCHED THEN
     UPDATE SET y = TRUE;

:EXPLAIN SELECT *
FROM small
WHERE EXISTS (SELECT * FROM medium WHERE medium.x = small.x);

:EXPLAIN SELECT *
FROM small
WHERE small.x IN (SELECT medium.x FROM medium);

:EXPLAIN SELECT *
FROM medium
WHERE NOT EXISTS (SELECT * FROM small WHERE small.x = 
medium.x);

:EXPLAIN SELECT *
FROM small
WHERE small.x NOT IN (SELECT medium.x FROM medium);

-- UNIQUE index guarantees at most one right row match
CREATE UNIQUE INDEX i_small ON small (x);

-- LEFT JOIN guarantees every left row is returned
:EXPLAIN SELECT medium.x FROM medium LEFT JOIN small USING (x);

