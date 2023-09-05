-- Generated from optimizer.pdf at https://momjian.us/presentations
-- This is intended to be run by psql so backslash commands are processed.

-- setup
\pset footer off
\pset null (null)

SELECT relname
FROM pg_class
ORDER BY 1
LIMIT 8;

SELECT substring(relname, 1, 1)
FROM pg_class
ORDER BY 1
LIMIT 8;

CREATE TEMPORARY TABLE sample (letter, junk) AS
        SELECT substring(relname, 1, 1), repeat('x', 250)
        FROM pg_class
        ORDER BY random();  -- add rows in random order

CREATE INDEX i_sample on sample (letter);

CREATE OR REPLACE FUNCTION lookup_letter(text) RETURNS SETOF 
text AS $$
BEGIN
RETURN QUERY EXECUTE '
        EXPLAIN SELECT letter 
        FROM sample
        WHERE letter = ''' || $1 || '''';
END
$$ LANGUAGE plpgsql;

WITH letters (letter, count) AS (
        SELECT  letter, COUNT(*)
        FROM sample
        GROUP BY 1
)
SELECT letter, count, (count * 100.0 / (SUM(count) OVER 
()))::numeric(4,1) AS "%"
FROM letters
ORDER BY 2 DESC;

EXPLAIN SELECT letter 
FROM sample
WHERE letter = 'p';

EXPLAIN SELECT letter 
FROM sample
WHERE letter = 'd';

EXPLAIN SELECT letter 
FROM sample
WHERE letter = 'i';

ANALYZE sample;

EXPLAIN SELECT letter 
FROM sample
WHERE letter = 'p';

EXPLAIN SELECT letter 
FROM sample
WHERE letter = 'd';

EXPLAIN SELECT letter 
FROM sample
WHERE letter = 'i';

WITH letter (letter, count) AS (
        SELECT letter, COUNT(*)
        FROM sample
        GROUP BY 1
)
SELECT letter AS l, count, lookup_letter(letter)
FROM letter
ORDER BY 2 DESC;


WITH letter (letter, count) AS (
        SELECT letter, COUNT(*)
        FROM sample
        GROUP BY 1
)
SELECT letter AS l, count,
        (SELECT * 
         FROM lookup_letter(letter) AS l2 
         LIMIT 1) AS lookup_letter
FROM letter
ORDER BY 2 DESC;

SET enable_seqscan = false;

SET enable_bitmapscan = false;

WITH letter (letter, count) AS (
        SELECT letter, COUNT(*)
        FROM sample
        GROUP BY 1
)
SELECT letter AS l, count,
        (SELECT * 
         FROM lookup_letter(letter) AS l2 
         LIMIT 1) AS lookup_letter
FROM letter
ORDER BY 2 DESC;

RESET ALL;

SELECT oid
FROM pg_proc
ORDER BY 1
LIMIT 8;

CREATE TEMPORARY TABLE sample1 (id, junk) AS
        SELECT oid, repeat('x', 250)
        FROM pg_proc
        ORDER BY random();  -- add rows in random order

CREATE TEMPORARY TABLE sample2 (id, junk) AS
        SELECT oid, repeat('x', 250)
        FROM pg_class
        ORDER BY random();  -- add rows in random order

EXPLAIN SELECT sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
WHERE sample1.id = 33;


EXPLAIN SELECT sample1.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
WHERE sample2.id > 33;





EXPLAIN SELECT sample1.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id);











EXPLAIN SELECT sample2.junk
FROM sample2 JOIN sample1 ON (sample2.id = sample1.id);

ANALYZE sample1;

ANALYZE sample2;

EXPLAIN SELECT sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id);

EXPLAIN SELECT sample1.junk
FROM sample1 RIGHT OUTER JOIN sample2 ON (sample1.id = 
sample2.id);

EXPLAIN SELECT sample1.junk
FROM sample1 CROSS JOIN sample2;

CREATE INDEX i_sample1 on sample1 (id);

CREATE INDEX i_sample2 on sample2 (id);

EXPLAIN SELECT sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
WHERE sample1.id = 33;



EXPLAIN SELECT sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
WHERE sample2.junk ~ '^aaa';

EXPLAIN SELECT sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
WHERE sample2.junk ~ '^xxx';

EXPLAIN SELECT sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
ORDER BY 1;

EXPLAIN SELECT sample2.id, sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
ORDER BY 1
LIMIT 1;

EXPLAIN SELECT sample2.id, sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
ORDER BY 1
LIMIT 10;

EXPLAIN SELECT sample2.id, sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
ORDER BY 1
LIMIT 100;

EXPLAIN SELECT sample2.id, sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
ORDER BY 1
LIMIT 1000;

-- updates the visibility map
VACUUM sample1, sample2;

EXPLAIN SELECT sample2.id, sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
ORDER BY 1
LIMIT 1000;

EXPLAIN SELECT sample2.id, sample2.junk
FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)
ORDER BY 1;

