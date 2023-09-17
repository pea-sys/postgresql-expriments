# Non-Relational

次の資料で紹介されていたスクリプトを元に Non-Relational 関数 の動作確認を行います。

---

スクリプトの提供元  
https://momjian.us/main/  
スライド  
https://momjian.us/main/writings/pgsql/non-relational.pdf

---

### [Setup]

```sql
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
psql -U postgres -p 5432 -d sample
sample=# \pset footer off
sample=# \pset null (null)
Null表示は"(null)"です。
```

### [1. Arrays]

```sql
sample=# CREATE TABLE employee (name TEXT PRIMARY KEY, certifications TEXT[]);INSERT INTO employee VALUES ('Bill', '{"CCNA", "ACSP", "CISSP"}');
SELECT * FROM employee;SELECT name FROM employee WHERE certifications @> '{ACSP}';
CREATE TABLE
INSERT 0 1
 name |  certifications
------+-------------------
 Bill | {CCNA,ACSP,CISSP}


 name
------
 Bill
```

### [Array Access]

```sql
sample=# SELECT certifications[1]FROM employee;
SELECT unnest(certifications)FROM employee;
 certifications
----------------
 CCNA

 unnest
--------
 CCNA
 ACSP
 CISSP
```

### [Array Unrolling]

```sql
sample=# SELECT name, unnest(certifications)FROM employee;
 name | unnest
------+--------
 Bill | CCNA
 Bill | ACSP
 Bill | CISSP
```

### [Array Creation]

```sql
sample=# SELECT DISTINCT relkind FROM pg_class ORDER BY 1;
SELECT array_agg(DISTINCT relkind) FROM pg_class;
 relkind
---------
 i
 r
 t
 v


 array_agg
-----------
 {i,r,t,v}
```

### [2. Range Types]

```Sql
sample=# CREATE TABLE car_rental (id SERIAL PRIMARY KEY, time_span TSTZRANGE);
INSERT INTO car_rental VALUES (DEFAULT, '[2016-05-03 09:00:00, 2016-05-11 12:00:00)');
SELECT * FROM car_rental WHERE time_span @> '2016-05-09 00:00:00'::timestamptz;SELECT * FROM car_rental WHERE time_span @> '2018-06-09 00:00:00'::timestamptz;
CREATE TABLE
INSERT 0 1
 id |                      time_span
----+-----------------------------------------------------
  1 | ["2016-05-03 09:00:00+09","2016-05-11 12:00:00+09")


 id | time_span
----+-----------
```

### [Range Type Indexing]

```sql
sample=# INSERT INTO car_rental (time_span)SELECT tstzrange(y, y + '1 day')FROM generate_series('2001-09-01 00:00:00'::timestamptz,  '2010-09-01 00:00:00'::timestamptz, '1 day') AS x(y);SELECT * FROM car_rental WHERE time_span @> '2007-08-01 00:00:00'::timestamptz;EXPLAIN SELECT * FROM car_rental WHERE time_span @> '2007-08-01 00:00:00'::timestamptz;
INSERT 0 3288
  id  |                      time_span
------+-----------------------------------------------------
 2162 | ["2007-08-01 00:00:00+09","2007-08-02 00:00:00+09")


                                 QUERY PLAN
-----------------------------------------------------------------------------
 Seq Scan on car_rental  (cost=0.00..64.69 rows=16 width=36)
   Filter: (time_span @> '2007-08-01 00:00:00+09'::timestamp with time zone)

sample=# CREATE INDEX car_rental_idx ON car_rental USING GIST (time_span);
EXPLAIN SELECT * FROM car_rental WHERE time_span @> '2007-08-01 00:00:00'::timestamptz;
CREATE INDEX
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Index Scan using car_rental_idx on car_rental  (cost=0.15..8.17 rows=1 width=26)
   Index Cond: (time_span @> '2007-08-01 00:00:00+09'::timestamp with time zone)
```

### [Exclusion Constraints]

```sql
sample=# ALTER TABLE car_rental ADD EXCLUDE USING GIST (time_span WITH &&);
INSERT INTO car_rental VALUES (DEFAULT, '[2003-04-01 00:00:00, 2003-04-01 00:00:01)');
ALTER TABLE
ERROR:  重複キーの値が排除制約"car_rental_time_span_excl"に違反しています
DETAIL:  キー (time_span)=(["2003-04-01 00:00:00+09","2003-04-01 00:00:01+09")) が既存のキー (time_span)=(["2003-04-01 00:00:00+09","2003-04-02 00:00:00+09")) と競合しています
```

### [3. Geometry]

```sql
sample=# CREATE TABLE dart (dartno SERIAL, location POINT);INSERT INTO dart (location)SELECT CAST('(' || random() * 100 || ',' || random() * 100 || ')' AS point)FROM generate_series(1, 1000);SELECT * FROM dart LIMIT 5;
CREATE TABLE
INSERT 0 1000
 dartno |                location
--------+----------------------------------------
      1 | (45.24266217705908,58.47964396648986)
      2 | (48.566052506108946,52.8229526958377)
      3 | (59.18191075390473,97.66626679248387)
      4 | (67.39166789369139,52.51927489073536)
      5 | (60.48876909564005,16.361242026354272)
```

### [Geometry Restriction]

```sql
sample=# SELECT * FROM dart WHERE location <@ '<(50, 50), 4>'::circle;EXPLAIN SELECT * FROM dart WHERE location <@ '<(50, 50), 4>'::circle;
 dartno |                location
--------+----------------------------------------
      2 | (48.566052506108946,52.8229526958377)
    130 | (51.58086862640865,52.73413822842619)
    471 | (49.805523985156874,53.81063854448775)
    790 | (51.25930941388563,47.62959652827641)


                      QUERY PLAN
------------------------------------------------------
 Seq Scan on dart  (cost=0.00..31.25 rows=2 width=20)
   Filter: (location <@ '<(50,50),4>'::circle)

```

### [Indexed Geometry Restriction]

```sql

sample=# CREATE INDEX dart_idx ON dart USING GIST (location);EXPLAIN SELECT * FROM dart WHERE location <@ '<(50, 50), 4>'::circle;
CREATE INDEX
                              QUERY PLAN
----------------------------------------------------------------------
 Index Scan using dart_idx on dart  (cost=0.14..8.16 rows=1 width=20)
   Index Cond: (location <@ '<(50,50),4>'::circle)
```

### [Geometry Indexes with LIMIT]

```sql
sample=# SELECT * FROM dart ORDER BY location <-> '(50, 50)'::point LIMIT 2;
EXPLAIN SELECT * FROM dart ORDER BY location <-> '(50, 50)'::point LIMIT 2;
 dartno |               location
--------+---------------------------------------
    790 | (51.25930941388563,47.62959652827641)
    130 | (51.58086862640865,52.73413822842619)


                                   QUERY PLAN
--------------------------------------------------------------------------------
 Limit  (cost=0.14..0.31 rows=2 width=28)
   ->  Index Scan using dart_idx on dart  (cost=0.14..84.14 rows=1000 width=28)
         Order By: (location <-> '(50,50)'::point)

```

※xml 省略

## [5. JSON Data Type]

### [Load JSON Data]

```sql
sample=# CREATE TABLE friend (id SERIAL, data JSON);

CREATE TABLE
sample=# COPY friend (data) FROM 'MOCK_DATA.json';

COPY 1000
sample=# SELECT * FROM friend ORDER BY 1 LIMIT 2;
 id |                                                             data
----+-------------------------------------------------------------------------------------------------------------------------------
  1 | {"first_name":"Phil","last_name":"Kitchiner","email":"pkitchiner0@apache.org","gender":"Female","ip_address":"93.213.184.46"}
  2 | {"first_name":"Ham","last_name":"Westcar","email":"hwestcar1@adobe.com","gender":"Male","ip_address":"189.36.58.228"}
```

### [Pretty Print JSON]

```sql
sample=# SELECT id, jsonb_pretty(data::jsonb) FROM friend ORDER BY 1 LIMIT 1;
 id |              jsonb_pretty
----+----------------------------------------
  1 | {                                     +
    |     "email": "pkitchiner0@apache.org",+
    |     "gender": "Female",               +
    |     "last_name": "Kitchiner",         +
    |     "first_name": "Phil",             +
    |     "ip_address": "93.213.184.46"     +
    | }

```

### [Access JSON Values]

```sql
sample=# SELECT data->>'email' FROM friend ORDER BY 1 LIMIT 5;
        ?column?
-------------------------
 aaleksashinqr@diigo.com
 aambroise56@apache.org
 aangroven8@myspace.com
 aardy5a@nasa.gov
 aarkell3m@histats.com
```

### [Concatenate JSON Values]

```sql
sample=# SELECT data->>'first_name' || ' ' ||  (data->>'last_name') FROM friend ORDER BY 1 LIMIT 5;
    ?column?
----------------
 Abagael Press
 Abagail Savery
 Abba MacMoyer
 Abdel Goligher
 Abigale Dawe
```

### [JSON Value Restrictions]

```sql
sample=# SELECT data->>'first_name' FROM friend WHERE data->>'last_name' = 'Kitchiner' ORDER BY 1;
 ?column?
----------
 Phil

sample=# SELECT data->>'first_name' FROM friend WHERE data::jsonb @> '{"last_name" : "Kitchiner"}' ORDER BY 1;
 ?column?
----------
 Phil
```

### [Single-Key JSON Index]

```sql
sample=# CREATE INDEX friend_idx ON friend ((data->>'last_name'));EXPLAIN SELECT data->>'first_name' FROM friend WHERE data->>'last_name' = 'Kitchiner' ORDER BY 1;
CREATE INDEX
                                  QUERY PLAN
-------------------------------------------------------------------------------
 Sort  (cost=17.14..17.15 rows=5 width=32)
   Sort Key: ((data ->> 'first_name'::text))
   ->  Bitmap Heap Scan on friend  (cost=4.31..17.08 rows=5 width=32)
         Recheck Cond: ((data ->> 'last_name'::text) = 'Kitchiner'::text)
         ->  Bitmap Index Scan on friend_idx  (cost=0.00..4.31 rows=5 width=0)
               Index Cond: ((data ->> 'last_name'::text) = 'Kitchiner'::text)
```

### [JSON Calculations]

```sql
sample=# SELECT data->>'first_name' || ' ' || (data->>'last_name'),       data->>'ip_address' FROM friend WHERE (data->>'ip_address')::inet <<= '172.0.0.0/8'::cidr ORDER BY 1;
     ?column?     |    ?column?
------------------+-----------------
 Glyn Crofthwaite | 172.45.224.200
 Laurella Heinle  | 172.61.167.116
 Lyell Lilywhite  | 172.89.200.245
 Minor Gettens    | 172.248.228.101

sample=# SELECT data->>'gender', COUNT(data->>'gender') FROM friend GROUP BY 1 ORDER BY 2 DESC;
  ?column?   | count
-------------+-------
 Male        |   466
 Female      |   422
 Genderqueer |    25
 Polygender  |    21
 Agender     |    20
 Non-binary  |    18
 Bigender    |    15
 Genderfluid |    13
```

## [6. JSONB]

### [JSON vs. JSONB Data Types]

```sql
sample=# SELECT '{"name" : "Jim", "name" : "Andy", "age" : 12}'::json;
ELECT '{"name" : "Jim", "name" : "Andy", "age" : 12}'::jsonb;
                     json
-----------------------------------------------
 {"name" : "Jim", "name" : "Andy", "age" : 12}


            jsonb
-----------------------------
 {"age": 12, "name": "Andy"}
```

### [JSONB Index]

```sql
sample=# CREATE TABLE friend2 (id SERIAL, data JSONB);
INSERT INTO friend2 SELECT * FROM friend;
CREATE TABLE
INSERT 0 1000
sample=# CREATE INDEX friend2_idx ON friend2 USING GIN (data);
CREATE INDEX
```

### [JSONB Index Queries]

```sql
sample=# SELECT data->>'first_name'FROM friend2 WHERE data @> '{"last_name" : "Pincott"}'ORDER BY 1;
EXPLAIN SELECT data->>'first_name' FROM friend2 WHERE data @> '{"last_name" : "Pincott"}' ORDER BY 1;
 ?column?
----------
 Raine


                                   QUERY PLAN
---------------------------------------------------------------------------------
 Sort  (cost=24.03..24.03 rows=1 width=32)
   Sort Key: ((data ->> 'first_name'::text))
   ->  Bitmap Heap Scan on friend2  (cost=20.00..24.02 rows=1 width=32)
         Recheck Cond: (data @> '{"last_name": "Pincott"}'::jsonb)
         ->  Bitmap Index Scan on friend2_idx  (cost=0.00..20.00 rows=1 width=0)
               Index Cond: (data @> '{"last_name": "Pincott"}'::jsonb)
```

### [JSONB Index Queries]

```sql
sample=# SELECT data->>'last_name'FROM friend2 WHERE data @> '{"first_name" : "Ham"}'ORDER BY 1;
 ?column?
----------
 Westcar


sample=# EXPLAIN SELECT data->>'last_name' FROM friend2 WHERE data::jsonb @> '{"first_name" : "Ham"}'ORDER BY 1;
                                   QUERY PLAN
---------------------------------------------------------------------------------
 Sort  (cost=24.03..24.03 rows=1 width=32)
   Sort Key: ((data ->> 'last_name'::text))
   ->  Bitmap Heap Scan on friend2  (cost=20.00..24.02 rows=1 width=32)
         Recheck Cond: (data @> '{"first_name": "Ham"}'::jsonb)
         ->  Bitmap Index Scan on friend2_idx  (cost=0.00..20.00 rows=1 width=0)
               Index Cond: (data @> '{"first_name": "Ham"}'::jsonb)
sample=# SELECT data->>'first_name' || ' ' || (data->>'last_name') FROM friend2 WHERE data @> '{"ip_address" : "69.179.181.7"}' ORDER BY 1;
     ?column?
------------------
 Ebeneser Sproson

sample=# EXPLAIN SELECT data->>'first_name' || ' ' || (data->>'last_name') FROM friend2 WHERE data @> '{"ip_address" : "69.179.181.7"}' ORDER BY 1;
                                          QUERY PLAN
----------------------------------------------------------------------------------------------
 Sort  (cost=24.03..24.04 rows=1 width=32)
   Sort Key: ((((data ->> 'first_name'::text) || ' '::text) || (data ->> 'last_name'::text)))
   ->  Bitmap Heap Scan on friend2  (cost=20.00..24.02 rows=1 width=32)
         Recheck Cond: (data @> '{"ip_address": "69.179.181.7"}'::jsonb)
         ->  Bitmap Index Scan on friend2_idx  (cost=0.00..20.00 rows=1 width=0)
               Index Cond: (data @> '{"ip_address": "69.179.181.7"}'::jsonb)
```

## [7. Row Types]

### []

```sql
sample=# CREATE TYPE drivers_license AS (state CHAR(2), id INTEGER, valid_until DATE);
CREATE TABLE truck_driver (id SERIAL, name TEXT, license DRIVERS_LICENSE);INSERT INTO truck_driver VALUES (DEFAULT, 'Jimbo Biggins', ('PA', 175319, '2017-03-12'));
CREATE TYPE
CREATE TABLE
INSERT 0 1

sample=# SELECT * FROM truck_driver;SELECT license FROM truck_driver;
 id |     name      |        license
----+---------------+------------------------
  1 | Jimbo Biggins | (PA,175319,2017-03-12)


        license
------------------------
 (PA,175319,2017-03-12)

sample=# SELECT (license).state FROM truck_driver;
 state
-------
 PA
```

### [8. Character Strings]

```sql
sample=# CREATE TABLE fortune (line TEXT);
CREATE TABLE

sample=# COPY fortune from E'fortunes' WITH (DELIMITER E'\x1F');
COPY 59042
```

### [8.1 Case Folding and Prefix]

```sql
sample=# SELECT * FROM fortune WHERE line = 'underdog';
SELECT * FROM fortune WHERE line = 'Underdog';
SELECT * FROM fortune WHERE lower(line) = 'underdog';
 line
------


   line
----------
 Underdog


   line
----------
 Underdog
```

### [Case Folding]

```sql
sample=# CREATE INDEX fortune_idx_text ON fortune (line);EXPLAIN SELECT * FROM fortune WHERE lower(line) = 'underdog';
CREATE INDEX
                         QUERY PLAN
-------------------------------------------------------------
 Seq Scan on fortune  (cost=0.00..1384.63 rows=295 width=36)
   Filter: (lower(line) = 'underdog'::text)
```

### [Indexed Case Folding]

```sql
sample=# CREATE INDEX fortune_idx_lower ON fortune (lower(line));
EXPLAIN SELECT * FROM fortune WHERE lower(line) = 'underdog';
CREATE INDEX
                                    QUERY PLAN
-----------------------------------------------------------------------------------
 Bitmap Heap Scan on fortune  (cost=10.70..464.77 rows=295 width=36)
   Recheck Cond: (lower(line) = 'underdog'::text)
   ->  Bitmap Index Scan on fortune_idx_lower  (cost=0.00..10.63 rows=295 width=0)
         Index Cond: (lower(line) = 'underdog'::text)
```

### [String Prefix]

```sql
sample=# SELECT line FROM fortune WHERE line LIKE 'Mop%' ORDER BY 1;
          line
-------------------------
 Mophobia, n.:
 Moping, melancholy mad:

sample=# EXPLAIN SELECT line FROM fortune WHERE line LIKE 'Mop%' ORDER BY 1;
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Index Only Scan using fortune_idx_text on fortune  (cost=0.41..4.44 rows=4 width=36)   Index Cond: ((line >= 'Mop'::text) AND (line < 'Moq'::text))
   Filter: (line ~~ 'Mop%'::text)
```

### [Indexed String Prefix]

```sql
sample=# CREATE INDEX fortune_idx_ops ON fortune (line text_pattern_ops);EXPLAIN SELECT line FROM fortune WHERE line LIKE 'Mop%' ORDER BY 1;
CREATE INDEX
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Index Only Scan using fortune_idx_text on fortune  (cost=0.41..4.44 rows=4 width=36)   Index Cond: ((line >= 'Mop'::text) AND (line < 'Moq'::text))
   Filter: (line ~~ 'Mop%'::text)
```

### [Case Folded String Prefix]

```sql
sample=# EXPLAIN SELECT line FROM fortune WHERE lower(line) LIKE 'mop%' ORDER BY 1;
                                        QUERY PLAN
------------------------------------------------------------------------------------------
 Sort  (cost=477.61..478.35 rows=295 width=36)
   Sort Key: line
   ->  Bitmap Heap Scan on fortune  (cost=11.44..465.51 rows=295 width=36)
         Filter: (lower(line) ~~ 'mop%'::text)
         ->  Bitmap Index Scan on fortune_idx_lower  (cost=0.00..11.36 rows=295 width=0)
               Index Cond: ((lower(line) >= 'mop'::text) AND (lower(line) < 'moq'::text))
```

### [Indexed Case Folded String Prefix]

```Sql
sample=# CREATE INDEX fortune_idx_ops_lower ON fortune (lower(line) text_pattern_ops);EXPLAIN SELECT line FROM fortune WHERE lower(line) LIKE 'mop%' ORDER BY 1;
CREATE INDEX
                                          QUERY PLAN
----------------------------------------------------------------------------------------------
 Sort  (cost=477.61..478.35 rows=295 width=36)
   Sort Key: line
   ->  Bitmap Heap Scan on fortune  (cost=11.44..465.51 rows=295 width=36)
         Filter: (lower(line) ~~ 'mop%'::text)
         ->  Bitmap Index Scan on fortune_idx_ops_lower  (cost=0.00..11.36 rows=295 width=0)
               Index Cond: ((lower(line) ~>=~ 'mop'::text) AND (lower(line) ~<~ 'moq'::text))
```

## [8.2. Full Text Search]

### [Tsvector and Tsquery]

```sql
sample=# SHOW default_text_search_config;
SELECT to_tsvector('I can hardly wait.');
SELECT to_tsquery('hardly & wait');
 default_text_search_config
----------------------------
 pg_catalog.simple


            to_tsvector
-----------------------------------
 'can':2 'hardly':3 'i':1 'wait':4


    to_tsquery
-------------------
 'hardly' & 'wait'

sample=# SELECT to_tsvector('I can hardly wait.') @@   to_tsquery('hardly & wait');
SELECT to_tsvector('I can hardly wait.') @@ to_tsquery('softly & wait');
 ?column?
----------
 t


 ?column?
----------
 f
```

### [Indexing Full Text Search]

```sql
sample=# CREATE INDEX fortune_idx_ts ON fortune USING GIN (to_tsvector('english', line));
CREATE INDEX
```

### [Full Text Search Queries]

```sql
sample=# SELECT line FROM fortune WHERE to_tsvector('english', line) @@ to_tsquery('panda');
                                 line
----------------------------------------------------------------------
         A giant panda bear is really a member of the raccoon family.

sample=# EXPLAIN SELECT line FROM fortune WHERE to_tsvector('english', line) @@ to_tsquery('panda');
                                         QUERY PLAN
--------------------------------------------------------------------------------------------
 Bitmap Heap Scan on fortune  (cost=14.54..615.37 rows=295 width=36)
   Recheck Cond: (to_tsvector('english'::regconfig, line) @@ to_tsquery('panda'::text))
   ->  Bitmap Index Scan on fortune_idx_ts  (cost=0.00..14.46 rows=295 width=0)
         Index Cond: (to_tsvector('english'::regconfig, line) @@ to_tsquery('panda'::text))
```

### [Complex Full Text Search Queries]

```sql
sample=# SELECT line FROM fortune WHERE to_tsvector('english', line) @@ to_tsquery('cat & sleep');
SELECT line FROM fortune WHERE to_tsvector('english', line) @@ to_tsquery('cat & (sleep | nap)');
                              line
-----------------------------------------------------------------
 People who take cat naps don't usually sleep in a cat's cradle.


                              line
-----------------------------------------------------------------
 People who take cat naps don't usually sleep in a cat's cradle.
 Q:      What is the sound of one cat napping?
```

### [Word Prefix Search]

```sql
sample=# SELECT line FROM fortune WHERE to_tsvector('english', line) @@      to_tsquery('english', 'zip:*')ORDER BY 1;
                                   line
---------------------------------------------------------------------------
 Bozo is the Brotherhood of Zips and Others.  Bozos are people who band
 Postmen never die, they just lose their zip.
 computer -- he's the one who's in trouble.  One round from an Uzi can zip
 far I've got two Bics, four Zippos and eighteen books of matches."
sample=# EXPLAIN SELECT line FROM fortune WHERE to_tsvector('english', line) @@      to_tsquery('english', 'zip:*')ORDER BY 1;
                                         QUERY PLAN
---------------------------------------------------------------------------------------------
 Sort  (cost=902.43..905.38 rows=1181 width=36)
   Sort Key: line
   ->  Bitmap Heap Scan on fortune  (cost=33.15..842.16 rows=1181 width=36)
         Recheck Cond: (to_tsvector('english'::regconfig, line) @@ '''zip'':*'::tsquery)
         ->  Bitmap Index Scan on fortune_idx_ts  (cost=0.00..32.86 rows=1181 width=0)
               Index Cond: (to_tsvector('english'::regconfig, line) @@ '''zip'':*'::tsquery)
```

### [8.3. Adjacent Letter Search]

```sql
sample=# SELECT line FROM fortune WHERE line ILIKE '%verit%' ORDER BY 1;
                                  line
-------------------------------------------------------------------------
         Passes wind, water, or out depending upon the severity of the
 In wine there is truth (In vino veritas).
 body.  There hangs from his belt a veritable arsenal of deadly weapons:

sample=# EXPLAIN SELECT line FROM fortune WHERE line ILIKE '%verit%'ORDER BY 1;
                           QUERY PLAN
-----------------------------------------------------------------
 Sort  (cost=1237.07..1237.08 rows=4 width=36)
   Sort Key: line
   ->  Seq Scan on fortune  (cost=0.00..1237.03 rows=4 width=36)
         Filter: (line ~~* '%verit%'::text)
```

### [Indexed Adjacent Letters]

```sql
sample=# CREATE EXTENSION pg_trgm;
CREATE INDEX fortune_idx_trgm ON fortune USING GIN (line gin_trgm_ops);
CREATE EXTENSION
CREATE INDEX

sample=# SELECT line FROM fortune WHERE line ILIKE '%verit%' ORDER BY 1;
                                  line
-------------------------------------------------------------------------
         Passes wind, water, or out depending upon the severity of the
 In wine there is truth (In vino veritas).
 body.  There hangs from his belt a veritable arsenal of deadly weapons:

sample=# EXPLAIN SELECT line FROM fortune WHERE line ILIKE '%verit%' ORDER BY 1;
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Sort  (cost=43.05..43.06 rows=4 width=36)
   Sort Key: line
   ->  Bitmap Heap Scan on fortune  (cost=28.03..43.01 rows=4 width=36)
         Recheck Cond: (line ~~* '%verit%'::text)
         ->  Bitmap Index Scan on fortune_idx_trgm  (cost=0.00..28.03 rows=4 width=0)
               Index Cond: (line ~~* '%verit%'::text)
```

### [Word Prefix Search]

```sql
sample=# SELECT line FROM fortune WHERE line ~* '(^|[^a-z])zip' ORDER BY 1;
                                   line
---------------------------------------------------------------------------
 Bozo is the Brotherhood of Zips and Others.  Bozos are people who band
 Postmen never die, they just lose their zip.
 computer -- he's the one who's in trouble.  One round from an Uzi can zip
 far I've got two Bics, four Zippos and eighteen books of matches."

sample=# EXPLAIN SELECT line FROM fortune WHERE line ~* '(^|[^a-z])zip'ORDER BY 1;
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Sort  (cost=27.05..27.06 rows=4 width=36)
   Sort Key: line
   ->  Bitmap Heap Scan on fortune  (cost=12.03..27.01 rows=4 width=36)
         Recheck Cond: (line ~* '(^|[^a-z])zip'::text)
         ->  Bitmap Index Scan on fortune_idx_trgm  (cost=0.00..12.03 rows=4 width=0)
               Index Cond: (line ~* '(^|[^a-z])zip'::text)
```

### [Similarity]

```sql
sample=# SELECT show_limit();
SELECT line, similarity(line, 'So much for the plan') FROM fortune WHERE line % 'So much for the plan'ORDER BY 1;
 show_limit
------------
        0.3


                         line                         | similarity
------------------------------------------------------+------------
 Oh, it's so much fun,                   When the CPU |      0.325
 So much                                              |  0.3809524
 There's so much plastic in this culture that         |  0.3043478

sample=# EXPLAIN SELECT show_limit();SELECT line, similarity(line, 'So much for the plan') FROM fortune WHERE line % 'So much for the plan'ORDER BY 1;
                QUERY PLAN
------------------------------------------
 Result  (cost=0.00..0.01 rows=1 width=4)


                         line                         | similarity
------------------------------------------------------+------------
 Oh, it's so much fun,                   When the CPU |      0.325
 So much                                              |  0.3809524
 There's so much plastic in this culture that         |  0.3043478
```

### [Indexes Created in this Section]

```sql
sample=# \d fortune and \di+
               テーブル"public.fortune"
  列  | タイプ | 照合順序 | Null 値を許容 | デフォルト
------+--------+----------+---------------+------------
 line | text   |          |               |
インデックス:
    "fortune_idx_lower" btree (lower(line))
    "fortune_idx_ops" btree (line text_pattern_ops)
    "fortune_idx_ops_lower" btree (lower(line) text_pattern_ops)
    "fortune_idx_text" btree (line)
    "fortune_idx_trgm" gin (line gin_trgm_ops)
    "fortune_idx_ts" gin (to_tsvector('english'::regconfig, line))


\d: 余分な引数"and"は無視されました
                                                     リレーション一覧
 スキーマ |            名前            |    タイプ    |  所有者  |  テーブル  | 永続性 | アクセスメソッド | サイズ  | 説明
----------+----------------------------+--------------+----------+------------+--------+------------------+---------+------
 public   | car_rental_idx             | インデックス | postgres | car_rental | 永続   | gist             | 264 kB  |
 public   | car_rental_pkey            | インデックス | postgres | car_rental | 永続   | btree            | 88 kB   |
 public   | car_rental_time_span_excl  | インデックス | postgres | car_rental | 永続   | gist             | 264 kB  |
 public   | car_rental_time_span_excl1 | インデックス | postgres | car_rental | 永続   | gist             | 264 kB  |
 public   | dart_idx                   | インデックス | postgres | dart       | 永続   | gist             | 72 kB   |
 public   | employee_pkey              | インデックス | postgres | employee   | 永続   | btree            | 16 kB   |
 public   | fortune_idx_lower          | インデックス | postgres | fortune    | 永続   | btree            | 3168 kB |
 public   | fortune_idx_ops            | インデックス | postgres | fortune    | 永続   | btree            | 3168 kB |
 public   | fortune_idx_ops_lower      | インデックス | postgres | fortune    | 永続   | btree            | 3168 kB |
 public   | fortune_idx_text           | インデックス | postgres | fortune    | 永続   | btree            | 3168 kB |
 public   | fortune_idx_trgm           | インデックス | postgres | fortune    | 永続   | gin              | 4856 kB |
 public   | fortune_idx_ts             | インデックス | postgres | fortune    | 永続   | gin              | 2056 kB |
 public   | friend2_idx                | インデックス | postgres | friend2    | 永続   | gin              | 304 kB  |
 public   | friend_idx                 | インデックス | postgres | friend     | 永続   | btree            | 48 kB   |
```

### [Use of the Contains Operator @> in this Presentation]

```
sample=# \do @>
                               演算子一覧
  スキーマ  | 名前 |   左辺の型    |   右辺の型    | 結果の型 |   説明
------------+------+---------------+---------------+----------+----------
 pg_catalog | @>   | aclitem[]     | aclitem       | boolean  | contains
 pg_catalog | @>   | anyarray      | anyarray      | boolean  | contains
 pg_catalog | @>   | anymultirange | anyelement    | boolean  | contains
 pg_catalog | @>   | anymultirange | anymultirange | boolean  | contains
 pg_catalog | @>   | anymultirange | anyrange      | boolean  | contains
 pg_catalog | @>   | anyrange      | anyelement    | boolean  | contains
 pg_catalog | @>   | anyrange      | anymultirange | boolean  | contains
 pg_catalog | @>   | anyrange      | anyrange      | boolean  | contains
 pg_catalog | @>   | box           | box           | boolean  | contains
 pg_catalog | @>   | box           | point         | boolean  | contains
 pg_catalog | @>   | circle        | circle        | boolean  | contains
 pg_catalog | @>   | circle        | point         | boolean  | contains
 pg_catalog | @>   | jsonb         | jsonb         | boolean  | contains
 pg_catalog | @>   | path          | point         | boolean  | contains
 pg_catalog | @>   | polygon       | point         | boolean  | contains
 pg_catalog | @>   | polygon       | polygon       | boolean  | contains
 pg_catalog | @>   | tsquery       | tsquery       | boolean  | contains
```
