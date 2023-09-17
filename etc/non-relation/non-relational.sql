-- Generated from non-relational.pdf at https://momjian.us/presentations
-- This is intended to be run by psql so backslash commands are processed.

-- setup
\pset footer off
\pset null (null)

CREATE TABLE employee 
(name TEXT PRIMARY KEY, certifications TEXT[]);

INSERT INTO employee
VALUES ('Bill', '{"CCNA", "ACSP", "CISSP"}');

SELECT * FROM employee;

SELECT name
FROM employee
WHERE certifications @> '{ACSP}';

SELECT certifications[1]
FROM employee;

SELECT unnest(certifications)
FROM employee;

SELECT name, unnest(certifications)
FROM employee;

SELECT DISTINCT relkind
FROM pg_class
ORDER BY 1;

SELECT array_agg(DISTINCT relkind)
FROM pg_class;

CREATE TABLE car_rental 
(id SERIAL PRIMARY KEY, time_span TSTZRANGE);

INSERT INTO car_rental
VALUES (DEFAULT, '[2016-05-03 09:00:00, 2016-05-11 12:00:00)');

SELECT *
FROM car_rental
WHERE time_span @> '2016-05-09 00:00:00'::timestamptz;

SELECT *
FROM car_rental
WHERE time_span @> '2018-06-09 00:00:00'::timestamptz;

INSERT INTO car_rental (time_span)
SELECT tstzrange(y, y + '1 day')
FROM generate_series('2001-09-01 00:00:00'::timestamptz,
                     '2010-09-01 00:00:00'::timestamptz, '1 
day') AS x(y);

SELECT *
FROM car_rental
WHERE time_span @> '2007-08-01 00:00:00'::timestamptz;

EXPLAIN SELECT *
FROM car_rental
WHERE time_span @> '2007-08-01 00:00:00'::timestamptz;

CREATE INDEX car_rental_idx ON car_rental
USING GIST (time_span);

EXPLAIN SELECT *
FROM car_rental
WHERE time_span @> '2007-08-01 00:00:00'::timestamptz;

ALTER TABLE car_rental ADD EXCLUDE USING GIST (time_span WITH 
&&);

INSERT INTO car_rental
VALUES (DEFAULT, '[2003-04-01 00:00:00, 2003-04-01 00:00:01)');

CREATE TABLE dart (dartno SERIAL, location POINT);

INSERT INTO dart (location)
SELECT CAST('(' || random() * 100 || ',' ||
            random() * 100 || ')' AS point)
FROM generate_series(1, 1000);

SELECT *
FROM dart
LIMIT 5;

-- find all darts within four units of point (50, 50)
SELECT *
FROM dart
WHERE location <@ '<(50, 50), 4>'::circle;

EXPLAIN SELECT *
FROM dart
WHERE location <@ '<(50, 50), 4>'::circle;

CREATE INDEX dart_idx ON dart
USING GIST (location);

EXPLAIN SELECT *
FROM dart
WHERE location <@ '<(50, 50), 4>'::circle;

-- find the two closest darts to (50, 50)
SELECT *
FROM dart
ORDER BY location <-> '(50, 50)'::point
LIMIT 2;

EXPLAIN SELECT *
FROM dart
ORDER BY location <-> '(50, 50)'::point
LIMIT 2;

CREATE TABLE printer (doc XML);

COPY printer from '/tmp/foomatic.xml';

SELECT (xpath('/option/arg_shortname/en', doc))
FROM printer
LIMIT 5;

SELECT (xpath('/option/arg_shortname/en', doc))[1]
FROM printer
LIMIT 5;

-- convert to XML text
SELECT (xpath('/option/arg_shortname/en/text()', doc))[1]
FROM printer
LIMIT 5;

-- convert to SQL text so we can do DISTINCT and ORDER BY
SELECT DISTINCT text((xpath('/option/arg_shortname/en/text()', 
doc))[1])
FROM printer
ORDER BY 1
LIMIT 5;

SELECT xpath('//driver/text()', doc)
FROM printer
ORDER BY random()
LIMIT 5;

SELECT DISTINCT unnest((xpath('//driver/text()', doc))::text[])
FROM printer
ORDER BY 1
LIMIT 5;

WITH driver (name) AS (
    SELECT DISTINCT unnest(xpath('//driver/text()', doc))::text
    FROM printer
)
SELECT name
FROM driver
WHERE name LIKE 'hp%'
ORDER BY 1;

-- download sample data from https://www.mockaroo.com/
-- remove 'id' column, output as JSON, uncheck 'array'
CREATE TABLE friend (id SERIAL, data JSON);

COPY friend (data) FROM '/tmp/MOCK_DATA.json';

SELECT *
FROM friend
ORDER BY 1
LIMIT 2;

SELECT id, jsonb_pretty(data::jsonb)
FROM friend
ORDER BY 1
LIMIT 1;

SELECT data->>'email'
FROM friend
ORDER BY 1
LIMIT 5;

SELECT data->>'first_name' || ' ' ||
       (data->>'last_name')
FROM friend
ORDER BY 1
LIMIT 5;

SELECT data->>'first_name'
FROM friend
WHERE data->>'last_name' = 'Banks'
ORDER BY 1;

-- the json way
SELECT data->>'first_name'
FROM friend
WHERE data::jsonb @> '{"last_name" : "Banks"}'
ORDER BY 1;

-- need double parentheses for the expression index
CREATE INDEX friend_idx ON friend ((data->>'last_name'));

EXPLAIN SELECT data->>'first_name'
FROM friend
WHERE data->>'last_name' = 'Banks'
ORDER BY 1;

SELECT data->>'first_name' || ' ' || (data->>'last_name'),
       data->>'ip_address'
FROM friend
WHERE (data->>'ip_address')::inet <<= '172.0.0.0/8'::cidr
ORDER BY 1;

SELECT data->>'gender', COUNT(data->>'gender')
FROM friend
GROUP BY 1
ORDER BY 2 DESC;

SELECT '{"name" : "Jim", "name" : "Andy", "age" : 12}'::json;

SELECT '{"name" : "Jim", "name" : "Andy", "age" : 12}'::jsonb;

CREATE TABLE friend2 (id SERIAL, data JSONB);

INSERT INTO friend2
SELECT * FROM friend;

-- jsonb_path_ops indexes are smaller and faster,
-- but do not support key-existence lookups.
CREATE INDEX friend2_idx ON friend2
USING GIN (data);

SELECT data->>'first_name'
FROM friend2
WHERE data @> '{"last_name" : "Banks"}'
ORDER BY 1;

EXPLAIN SELECT data->>'first_name'
FROM friend2
WHERE data @> '{"last_name" : "Banks"}'
ORDER BY 1;                 QUERY PLAN
----------------------------------------------------------------…
 Sort  (cost=24.03..24.04 rows=1 width=139)
   Sort Key: ((data ->> 'first_name'::text))
   ->  Bitmap Heap Scan on friend2  (cost=20.01..24.02 rows=1 …
         Recheck Cond: (data @> '{"last_name": 
"Banks"}'::jsonb)
         ->  Bitmap Index Scan on friend2_idx  
(cost=0.00..20.01 ……
               Index Cond: (data @> '{"last_name": 
"Banks"}'::js…
SELECT data->>'last_name'
FROM friend2
WHERE data @> '{"first_name" : "Jane"}'
ORDER BY 1;

EXPLAIN SELECT data->>'last_name'
FROM friend2
WHERE data::jsonb @> '{"first_name" : "Jane"}'
ORDER BY 1;                 QUERY PLAN
----------------------------------------------------------------…
 Sort  (cost=24.03..24.04 rows=1 width=139)
   Sort Key: ((data ->> 'last_name'::text))
   ->  Bitmap Heap Scan on friend2  (cost=20.01..24.02 rows=1 …
         Recheck Cond: (data @> '{"first_name": 
"Jane"}'::jsonb)
         ->  Bitmap Index Scan on friend2_idx  
(cost=0.00..20.01 …
               Index Cond: (data @> '{"first_name": 
"Jane"}'::js…
SELECT data->>'first_name' || ' ' || (data->>'last_name')
FROM friend2
WHERE data @> '{"ip_address" : "62.212.235.80"}'
ORDER BY 1;

EXPLAIN SELECT data->>'first_name' || ' ' || 
(data->>'last_name')
FROM friend2
WHERE data @> '{"ip_address" : "62.212.235.80"}'
ORDER BY 1;                 QUERY PLAN
-----------------------------------------------------------------…
 Sort  (cost=24.04..24.05 rows=1 width=139)
   Sort Key: ((((data ->> 'first_name'::text) || ' '::text) || …
   ->  Bitmap Heap Scan on friend2  (cost=20.01..24.03 rows=1 …
         Recheck Cond: (data @> '{"ip_address": 
"62.212.235.80"}'…
         ->  Bitmap Index Scan on friend2_idx  
(cost=0.00..20.01 …
               Index Cond: (data @> '{"ip_address": 
"62.212.235.…
CREATE TYPE drivers_license AS 
(state CHAR(2), id INTEGER, valid_until DATE);

CREATE TABLE truck_driver 
(id SERIAL, name TEXT, license DRIVERS_LICENSE);

INSERT INTO truck_driver
VALUES (DEFAULT, 'Jimbo Biggins', ('PA', 175319, 
'2017-03-12'));

SELECT *
FROM truck_driver;

SELECT license
FROM truck_driver;

-- parentheses are necessary
SELECT (license).state
FROM truck_driver;

CREATE TABLE fortune (line TEXT);

COPY fortune FROM '/tmp/fortunes' WITH (DELIMITER E'\x1F');

SELECT * FROM fortune WHERE line = 'underdog';

SELECT * FROM fortune WHERE line = 'Underdog';

SELECT * FROM fortune WHERE lower(line) = 'underdog';

CREATE INDEX fortune_idx_text ON fortune (line);

EXPLAIN SELECT * FROM fortune WHERE lower(line) = 'underdog';

CREATE INDEX fortune_idx_lower ON fortune (lower(line));

EXPLAIN SELECT * FROM fortune WHERE lower(line) = 'underdog';

SELECT line
FROM fortune
WHERE line LIKE 'Mop%'
ORDER BY 1;

EXPLAIN SELECT line
FROM fortune
WHERE line LIKE 'Mop%'
ORDER BY 1;

-- The default op class does string ordering of non-ASCII
-- collations, but not partial matching.  text_pattern_ops
-- handles prefix matching, but not ordering.
CREATE INDEX fortune_idx_ops ON fortune (line 
text_pattern_ops);

EXPLAIN SELECT line
FROM fortune
WHERE line LIKE 'Mop%'
ORDER BY 1;

EXPLAIN SELECT line
FROM fortune
WHERE lower(line) LIKE 'mop%'
ORDER BY 1;

CREATE INDEX fortune_idx_ops_lower ON fortune 
(lower(line) text_pattern_ops);

EXPLAIN SELECT line
FROM fortune
WHERE lower(line) LIKE 'mop%'
ORDER BY 1;

SHOW default_text_search_config;

SELECT to_tsvector('I can hardly wait.');

SELECT to_tsquery('hardly & wait');

SELECT to_tsvector('I can hardly wait.') @@
       to_tsquery('hardly & wait');

SELECT to_tsvector('I can hardly wait.') @@
       to_tsquery('softly & wait');

CREATE INDEX fortune_idx_ts ON fortune
USING GIN (to_tsvector('english', line));

SELECT line
FROM fortune
WHERE to_tsvector('english', line) @@ to_tsquery('pandas');

EXPLAIN SELECT line
FROM fortune 
WHERE to_tsvector('english', line) @@ to_tsquery('pandas');

SELECT line
FROM fortune
WHERE to_tsvector('english', line) @@ to_tsquery('cat & 
sleep');

SELECT line
FROM fortune 
WHERE to_tsvector('english', line) @@ to_tsquery('cat & (sleep 
| nap)');

SELECT line
FROM fortune
WHERE to_tsvector('english', line) @@
      to_tsquery('english', 'zip:*')
ORDER BY 1;


EXPLAIN SELECT line
FROM fortune
WHERE to_tsvector('english', line) @@
      to_tsquery('english', 'zip:*')
ORDER BY 1;



-- ILIKE is case-insensitive LIKE
SELECT line
FROM fortune
WHERE line ILIKE '%verit%'
ORDER BY 1;

EXPLAIN SELECT line
FROM fortune
WHERE line ILIKE '%verit%'
ORDER BY 1;

CREATE EXTENSION pg_trgm;

CREATE INDEX fortune_idx_trgm ON fortune
USING GIN (line gin_trgm_ops);

SELECT line
FROM fortune
WHERE line ILIKE '%verit%'
ORDER BY 1;

EXPLAIN SELECT line
FROM fortune
WHERE line ILIKE '%verit%'
ORDER BY 1;

-- ~* is case-insensitive regular expression
SELECT line
FROM fortune
WHERE line ~* '(^|[^a-z])zip'
ORDER BY 1;


EXPLAIN SELECT line
FROM fortune
WHERE line ~* '(^|[^a-z])zip'
ORDER BY 1;

SELECT show_limit();

SELECT line, similarity(line, 'So much for the plan')
FROM fortune
WHERE line % 'So much for the plan'
ORDER BY 1;

EXPLAIN SELECT line, similarity(line, 'So much for the plan')
FROM fortune
WHERE line % 'So much for the plan'
ORDER BY 1;

\dt+ fortune
\d fortune and \di+
\do @>
