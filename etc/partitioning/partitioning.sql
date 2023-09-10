-- Generated from partitioning.pdf at https://momjian.us/presentations
-- This is intended to be run by psql so backslash commands are processed.

-- setup
\pset footer off
\pset null (null)

CREATE TABLE range_partitioned (name TEXT)
PARTITION BY RANGE (name);

CREATE TABLE range_partition_less_j
PARTITION OF range_partitioned
FOR VALUES FROM (MINVALUE) TO ('j');

CREATE TABLE range_partition_j_to_s
PARTITION OF range_partitioned
FOR VALUES FROM ('j') TO ('s');

CREATE TABLE range_partition_s_greater
PARTITION OF range_partitioned
FOR VALUES FROM ('s') TO (MAXVALUE);

-- Range partitioned tables require DEFAULT partitions for NULL 
-- CHECK prevents non-NULLs and avoids partition scan checking 
-- values that might be in the newly-created partition.
CREATE TABLE range_partition_nulls
PARTITION OF range_partitioned
(CHECK (name IS NULL))
DEFAULT;

\d+ range_partitioned
CREATE TABLE hash_partitioned (name TEXT)
PARTITION BY HASH (name);

CREATE TABLE hash_partition_mod_0
PARTITION OF hash_partitioned
FOR VALUES WITH (MODULUS 3, REMAINDER 0);

CREATE TABLE hash_partition_mod_1
PARTITION OF hash_partitioned
FOR VALUES WITH (MODULUS 3, REMAINDER 1);

CREATE TABLE hash_partition_mod_2
PARTITION OF hash_partitioned
FOR VALUES WITH (MODULUS 3, REMAINDER 2);

\d+ hash_partitioned
CREATE TYPE employment_status_type AS ENUM ('employed', 
'unemployed', 'retired');

CREATE TABLE list_partitioned (
    name TEXT,
    employment_status employment_status_type
)
PARTITION BY LIST (employment_status);

CREATE TABLE list_partition_employed
PARTITION OF list_partitioned
FOR VALUES IN ('employed');

CREATE TABLE list_partition_unemployed
PARTITION OF list_partitioned
FOR VALUES IN ('unemployed');

-- allow NULL partition key values
CREATE TABLE list_partition_retired_and_null
PARTITION OF list_partitioned
FOR VALUES IN ('retired', NULL);

\d+ list_partitioned
-- This method of generating random data is explained at
-- https://momjian.us/main/blogs/pgblog/2012.html\#July_24_2012
INSERT INTO range_partitioned
SELECT
(
    SELECT initcap(string_agg(x, ''))
    FROM (
        SELECT chr(ascii('a') + floor(random() * 26)::integer)
        FROM generate_series(1, 2 + (random() * 8)::integer + b 
* 0)
    ) AS y(x)
)
FROM generate_series(1, 100000) AS a(b);

INSERT INTO hash_partitioned
SELECT
(
    SELECT initcap(string_agg(x, ''))
    FROM (
        SELECT chr(ascii('a') + floor(random() * 26)::integer)
        FROM generate_series(1, 2 + (random() * 8)::integer + b 
* 0)
    ) AS y(x)
)
FROM generate_series(1, 100000) AS a(b);

INSERT INTO list_partitioned
SELECT
(
    SELECT initcap(string_agg(x, ''))
    FROM (
        SELECT chr(ascii('a') + floor(random() * 26)::integer)
        FROM generate_series(1, 2 + (random() * 8)::integer + b 
* 0)
    ) AS y(x)
),
(
    SELECT CASE floor(random() * 3 + b * 0)
	           WHEN 0 THEN 'employed'::employment_status_type
               WHEN 1 THEN 'unemployed'::employment_status_type
               WHEN 2 THEN 'retired'::employment_status_type
	       END
)
FROM generate_series(1, 100000) AS a(b);

INSERT INTO range_partitioned VALUES (NULL);

INSERT INTO hash_partitioned VALUES (NULL);

INSERT INTO list_partitioned VALUES ('test', NULL);

CREATE INDEX i_range_partitioned ON range_partitioned (name);

CREATE INDEX i_hash_partitioned ON hash_partitioned (name);

CREATE INDEX i_list_partitioned ON list_partitioned (name);

ANALYZE;

-- NULLs are stored in the DEFAULT range partition.
SELECT *, tableoid::regclass
FROM  range_partitioned
WHERE name IS NULL;

-- NULLs are always stored in the REMAINDER 0 hash partition;

-- see 
SELECT *, tableoid::regclass
FROM  hash_partitioned
WHERE name IS NULL;

-- NULLs are stored in the list partition for NULL values.
SELECT *, tableoid::regclass
FROM  list_partitioned
WHERE employment_status IS NULL;

SELECT *, tableoid::regclass
FROM  range_partitioned
ORDER BY 2, 1
LIMIT 5;

WITH sample AS
(
    SELECT *, tableoid::regclass
    FROM  range_partitioned
    ORDER BY random()
    LIMIT 5
)
SELECT * FROM sample
ORDER BY 2, 1;

WITH sample AS
(
    SELECT *, tableoid::regclass
    FROM  hash_partitioned
    ORDER BY random()
    LIMIT 5
)
SELECT * FROM sample
ORDER BY 2, 1;

WITH sample AS
(
    SELECT *, tableoid::regclass
    FROM  list_partitioned
    ORDER BY random()
    LIMIT 5
)
SELECT * FROM sample
ORDER BY 3, 2, 1;

-- Use lower case for range boundaries if your collation sorts 
-- e.g., range 'j' to 's' would include 'j', but 'J' to 'S' 
-- not case-insensitive equal to 'J'.
SHOW lc_collate;

-- Case ordering ignored because of case-insensitive 
-- https://www.unicode.org/reports/tr10/#Scope
SELECT 'a' < 'J' AND 'J' < 'z';

SELECT 'ja' < 'Jb' AND 'Jc' < 'jd';

-- Case ordering only honored for case-insensitive equality.
SELECT 'ja' < 'Ja';

SELECT 'island' < 'Island' AND 'islaNd' < 'iSland';

\set EXPLAIN 'EXPLAIN (COSTS OFF)'
:EXPLAIN SELECT *
FROM range_partitioned
WHERE name IS NULL;

-- NULLs are always stored in the REMAINDER 0 hash partition.
:EXPLAIN SELECT *
FROM hash_partitioned
WHERE name IS NULL;

:EXPLAIN SELECT *
FROM list_partitioned
WHERE employment_status IS NULL;

:EXPLAIN SELECT *
FROM range_partitioned
WHERE name = 'Ma';

:EXPLAIN SELECT *
FROM hash_partitioned
WHERE name = 'Ma';

:EXPLAIN SELECT *
FROM  list_partitioned
WHERE employment_status = 'retired';

:EXPLAIN SELECT *
FROM list_partitioned
WHERE employment_status = 'retired' AND
      name = 'Ma';

\d+ list_partitioned
PREPARE part_test AS
SELECT *
FROM range_partitioned
WHERE name = $1;

:EXPLAIN  EXECUTE part_test('Ba');

:EXPLAIN  EXECUTE part_test('Ma');

:EXPLAIN  EXECUTE part_test('Ta');

\set EXPLAIN_ANALYZE 'EXPLAIN (ANALYZE, SUMMARY OFF, TIMING OFF, COSTS OFF)'
-- force a generic plan
SET plan_cache_mode TO force_generic_plan;

-- Pruning happens during executor initialization
:EXPLAIN_ANALYZE EXECUTE part_test('Ba');

:EXPLAIN_ANALYZE EXECUTE part_test('Ma');

:EXPLAIN_ANALYZE EXECUTE part_test('Ta');

RESET plan_cache_mode;

-- IMMUTABLE function calls are evaluated in the optimizer.
\do+ ||
\x on
\df+ textcat
\x off
:EXPLAIN_ANALYZE SELECT *, tableoid::regclass
FROM range_partitioned
WHERE name = 'M' || 'a';

-- STABLE function calls can also cause this.
\x on
\df+ concat
\x off
-- pruning happens during executor initialization
:EXPLAIN_ANALYZE SELECT *, tableoid::regclass
FROM range_partitioned
WHERE name = concat('M', 'a');

CREATE TABLE nested_outer (name) AS VALUES ('Pa'), ('Qa'), 
('Ra');

ANALYZE nested_outer;

-- pruning happens during executor running
:EXPLAIN_ANALYZE SELECT *
FROM range_partitioned
WHERE name IN (SELECT * FROM nested_outer);

-- pruning happens during executor running
:EXPLAIN_ANALYZE SELECT *
FROM nested_outer JOIN range_partitioned USING (name);

-- partitionwise_aggregate is disabled by default.
:EXPLAIN_ANALYZE SELECT name, COUNT(*)
FROM range_partitioned
GROUP BY name;

:EXPLAIN_ANALYZE SELECT name, COUNT(*)
FROM hash_partitioned
GROUP BY name;

:EXPLAIN_ANALYZE SELECT employment_status, COUNT(*)
FROM list_partitioned
GROUP BY employment_status;

SET enable_partitionwise_aggregate = true;

-- needed because the cost of combining per-partition 
-- with many distinct values is high
SET cpu_tuple_cost = 0;

:EXPLAIN_ANALYZE SELECT name, COUNT(*)
FROM range_partitioned
GROUP BY name;

:EXPLAIN_ANALYZE SELECT name, COUNT(*)
FROM hash_partitioned
GROUP BY name;

-- not needed for the next query because few distinct values
RESET cpu_tuple_cost;

:EXPLAIN_ANALYZE SELECT employment_status, COUNT(*)
FROM list_partitioned
GROUP BY employment_status;

RESET enable_partitionwise_aggregate;

CREATE TABLE range_partitioned2 (name TEXT)
PARTITION BY RANGE (name);

CREATE TABLE range_partition_less_j2
PARTITION OF range_partitioned2
FOR VALUES FROM (MINVALUE) TO ('j');

CREATE TABLE range_partition_j_to_s2
PARTITION OF range_partitioned2
FOR VALUES FROM ('j') TO ('s');

CREATE TABLE range_partition_s_greater2
PARTITION OF range_partitioned2
FOR VALUES FROM ('s') TO (MAXVALUE);

CREATE TABLE range_partition_nulls2
PARTITION OF range_partitioned2
(CHECK (name IS NULL))
DEFAULT;

INSERT INTO range_partitioned2
SELECT
(
    SELECT initcap(string_agg(x, ''))
    FROM (
        SELECT chr(ascii('a') + floor(random() * 26)::integer)
        FROM generate_series(1, 2 + (random() * 8)::integer + b 
* 0)
    ) AS y(x)
)
FROM generate_series(1, 100000) AS a(b);

ANALYZE;

-- partitionwise_aggregate is disabled by default.
:EXPLAIN_ANALYZE SELECT *
FROM range_partitioned JOIN range_partitioned2 USING (name);

SET enable_partitionwise_join = true;

:EXPLAIN_ANALYZE SELECT *
FROM range_partitioned JOIN range_partitioned2 USING (name);

CREATE TABLE month_partitioned (day DATE, temperature 
NUMERIC(5,2))
PARTITION BY RANGE (day);

CREATE TABLE month_partition_2023_01
PARTITION OF month_partitioned
FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

CREATE TABLE month_partition_2023_02
PARTITION OF month_partitioned
FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');

CREATE TABLE month_partition_2023_03
PARTITION OF month_partitioned
FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');

CREATE TABLE month_partition_other
PARTITION OF month_partitioned
DEFAULT;

INSERT INTO month_partitioned
SELECT
(
    SELECT '2023-01-01'::date +
	       floor(random() * ('2023-04-01'::date - 
'2023-01-01'::date) + b * 0)::integer
),
(
    SELECT floor(random() * 10000) / 100 + b * 0
)
FROM generate_series(1, 100000) AS a(b);

CREATE INDEX i_month_partitioned ON month_partitioned (day);

ANALYZE;

WITH sample AS
(
    SELECT *, tableoid::regclass
    FROM  month_partitioned
    ORDER BY random()
    LIMIT 5
)
SELECT * FROM sample
ORDER BY 3, 1;

:EXPLAIN_ANALYZE  SELECT *
FROM month_partitioned
WHERE day = '2023-02-01';

INSERT INTO month_partitioned VALUES ('2023-05-01', 87.31);

:EXPLAIN_ANALYZE SELECT *
FROM  month_partitioned
WHERE day = '2023-05-01';

INSERT INTO month_partitioned VALUES (NULL, 46.24);

:EXPLAIN_ANALYZE SELECT *
FROM  month_partitioned
WHERE day IS NULL;

ALTER TABLE month_partitioned DETACH PARTITION 
month_partition_other;

INSERT INTO month_partitioned VALUES (NULL, 46.24);

ALTER TABLE month_partitioned ATTACH PARTITION 
month_partition_other DEFAULT;

-- Simulate CURRENT_DATE by using the STABLE function concat().
\set CURRENT_DATE concat('''2023-02-01''' || '''''')::date
:EXPLAIN_ANALYZE SELECT *
FROM month_partitioned
WHERE day = :CURRENT_DATE;

CREATE TABLE month_partition_2023_04
PARTITION OF month_partitioned
FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');

DROP TABLE month_partition_2023_01;

SET timezone = 'America/New_York';

CREATE TABLE month_ts_tz_partitioned (event_time TIMESTAMP WITH 
TIME ZONE, temperature NUMERIC(5,2))
PARTITION BY RANGE (event_time);

-- date evaluated at creation time
CREATE TABLE month_ts_tz_partition_2023_01
PARTITION OF month_ts_tz_partitioned
FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

CREATE TABLE month_ts_tz_partition_2023_02
PARTITION OF month_ts_tz_partitioned
FOR VALUES FROM ('2023-02-01') TO ('2023-03-01');

CREATE TABLE month_ts_tz_partition_2023_03
PARTITION OF month_ts_tz_partitioned
FOR VALUES FROM ('2023-03-01') TO ('2023-04-01');

CREATE TABLE month_ts_tz_partition_other
PARTITION OF month_ts_tz_partitioned
DEFAULT;

SELECT EXTRACT(EPOCH FROM '2023-01-01'::date);

SELECT EXTRACT(EPOCH FROM '2023-01-01 
00:00:00-00'::timestamptz);

SELECT EXTRACT(EPOCH FROM '2023-01-01'::timestamptz);

SELECT EXTRACT(EPOCH FROM '2023-01-01 
00:00:00-05'::timestamptz);

INSERT INTO month_ts_tz_partitioned
SELECT
(
    SELECT '2023-01-01 00:00:00'::timestamptz +
	       (floor(random() *
              (extract(EPOCH FROM '2023-04-01'::timestamptz) -
               extract(EPOCH FROM '2023-01-01'::timestamptz)) +
              b * 0)::integer || 'seconds')::interval
),
(
    SELECT floor(random() * 10000) / 100 + b * 0
)
FROM generate_series(1, 100000) AS a(b);

-- add row to the DEFAULT partition
INSERT INTO month_ts_tz_partitioned VALUES ('2023-04-05 
00:00:00', 50);

CREATE INDEX i_month_ts_tz_partitioned ON 
month_ts_tz_partitioned (event_time);

ANALYZE;

\d+ month_ts_tz_partitioned
SELECT CURRENT_TIMESTAMP;

SELECT *, tableoid::regclass
FROM  month_ts_tz_partitioned
ORDER BY 1
LIMIT 1;

SET timezone = 'Asia/Tokyo';

SELECT CURRENT_TIMESTAMP;

SELECT *, tableoid::regclass
FROM  month_ts_tz_partitioned
ORDER BY 1
LIMIT 1;

\d+ month_ts_tz_partitioned
SET timezone = 'UTC';

SELECT *, tableoid::regclass
FROM  month_ts_tz_partitioned
ORDER BY 1
LIMIT 1;

\d+ month_ts_tz_partitioned
SET timezone = 'America/New_York';

:EXPLAIN_ANALYZE SELECT *
FROM month_ts_tz_partitioned
WHERE date(event_time) = '2023-02-05';

:EXPLAIN_ANALYZE SELECT *
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-02-05' AND
      event_time <  '2023-02-06';

-- simulate CURRENT_TIMESTAMP by using the STABLE function 
\set CURRENT_TIMESTAMP concat('''2023-02-05 23:43:51''' || '''''')::timestamptz
-- pruning happening during executor initialization
:EXPLAIN_ANALYZE SELECT *
FROM month_ts_tz_partitioned
WHERE event_time >  :CURRENT_TIMESTAMP - '24 hours'::interval 
AND
      event_time <= :CURRENT_TIMESTAMP;

:EXPLAIN_ANALYZE SELECT *
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00';

SELECT COUNT(*)
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00';

SELECT *, tableoid::regclass
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00'
ORDER BY 1
LIMIT 1;

SELECT *, tableoid::regclass
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00'
ORDER BY 1 DESC
LIMIT 1;

SET timezone = 'Asia/Tokyo';

:EXPLAIN_ANALYZE SELECT *
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00';

SELECT COUNT(*)
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00';

SELECT *, tableoid::regclass
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00'
ORDER BY 1
LIMIT 1;

SELECT *, tableoid::regclass
FROM month_ts_tz_partitioned
WHERE event_time >= '2023-03-01 00:00:00' AND
      event_time <  '2023-03-02 00:00:00'
ORDER BY 1 DESC
LIMIT 1;

-- caused by mismatch with America/New_York time zone 
CREATE TABLE month_ts_tz_partition_2023_04
PARTITION OF month_ts_tz_partitioned
FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');


SET timezone = 'America/New_York';

-- caused by daylight saving time change
CREATE TABLE month_ts_tz_partition_2023_04
PARTITION OF month_ts_tz_partitioned
FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');

BEGIN WORK;

-- lock table and/or detach DEFAULT partition?
CREATE TEMP TABLE tmp_default AS
SELECT *
FROM month_ts_tz_partition_other
WHERE event_time >= '2023-04-01 00:00:00' AND
      event_time <  '2023-05-01 00:00:00';

DELETE FROM month_ts_tz_partition_other
WHERE event_time >= '2023-04-01 00:00:00' AND
      event_time <  '2023-05-01 00:00:00';

CREATE TABLE month_ts_tz_partition_2023_04
PARTITION OF month_ts_tz_partitioned
FOR VALUES FROM ('2023-04-01') TO ('2023-05-01');

INSERT INTO month_ts_tz_partitioned
SELECT * FROM tmp_default;

SELECT * FROM  month_ts_tz_partition_other;

COMMIT;

SELECT * FROM  month_ts_tz_partition_2023_04;

SELECT * FROM  month_ts_tz_partition_other;

SELECT *, tableoid::regclass
FROM range_partitioned
WHERE name = 'Ma'
ORDER BY 2, 1;

UPDATE range_partitioned
SET name = 'zz_' || name
WHERE name = 'Ma';

SELECT *, tableoid::regclass
FROM range_partitioned
WHERE name = 'zz_Ma'
ORDER BY 2, 1;

COMMENT ON TABLE range_partitioned IS 'Section 2';

COMMENT ON TABLE hash_partitioned IS 'Section 2';

COMMENT ON TABLE list_partitioned IS 'Section 2';

COMMENT ON TABLE range_partitioned2 IS 'Section 4';

COMMENT ON TABLE month_partitioned IS 'Section 5';

COMMENT ON TABLE month_ts_tz_partitioned IS 'Section 5';

\dPt+
