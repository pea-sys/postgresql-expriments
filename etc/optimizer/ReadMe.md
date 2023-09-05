# Optimizer

次の資料で紹介されていたスクリプトを元に optimizer の動作確認を行います。

---

スクリプトの提供元  
https://momjian.us/main/  
スライド  
https://momjian.us/main/writings/pgsql/optimizer.pdf

---

### [Setup]

```
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
psql -U postgres -p 5432 -d sample
sample=# \pset footer off
sample=# \pset null (null)
Null表示は"(null)"です。
```

### [A Simple Example Using pg_class.relname]

```sql
sample=# SELECT relname FROM pg_class ORDER BY 1 LIMIT 8;
              relname
-----------------------------------
 _pg_foreign_data_wrappers
 _pg_foreign_servers
 _pg_foreign_table_columns
 _pg_foreign_tables
 _pg_user_mappings
 administrable_role_authorizations
 applicable_roles
 attributes
```

### [Let’s Use Just the First Letter of pg_class.relname]

```sql
sample=# SELECT substring(relname, 1, 1) FROM pg_class ORDER BY 1 LIMIT 8;
 substring
-----------
 _
 _
 _
 _
 _
 a
 a
 a
```

### [Create a Temporary Table with an Index]

```sql
sample=# CREATE TEMPORARY TABLE sample (letter, junk) AS SELECT substring(relname, 1, 1), repeat('x', 250) FROM pg_class ORDER BY random();
CREATE INDEX i_sample on sample (letter);
SELECT 417
CREATE INDEX
```

### [Create an EXPLAIN Function]

```sql
sample=# CREATE OR REPLACE FUNCTION lookup_letter(text) RETURNS SETOF text AS $$BEGIN RETURN QUERY EXECUTE ' EXPLAIN SELECT letter FROM sample WHERE letter = ''' || $1 || '''';END$$ LANGUAGE plpgsql;
CREATE FUNCTION
```

### [What is the Distribution of the sample Table?]

```sql
sample=# WITH letters (letter, count) AS (SELECT  letter, COUNT(*) FROM sample GROUP BY 1) SELECT letter, count, (count * 100.0 / (SUM(count) OVER ()))::numeric(4,1) AS "%"FROM letters ORDER BY 2 DESC;
 letter | count |  %
--------+-------+------
 p      |   342 | 82.0
 c      |    13 |  3.1
 r      |    12 |  2.9
 l      |     6 |  1.4
 f      |     6 |  1.4
 s      |     6 |  1.4
 t      |     6 |  1.4
 _      |     5 |  1.2
 u      |     5 |  1.2
 d      |     4 |  1.0
 v      |     4 |  1.0
 a      |     3 |  0.7
 i      |     2 |  0.5
 e      |     2 |  0.5
 k      |     1 |  0.2
```

### [Is the Distribution Important?]

```sql
sample=# EXPLAIN SELECT letter FROM sample WHERE letter = 'p';
                              QUERY PLAN
-----------------------------------------------------------------------
 Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=32)
   Recheck Cond: (letter = 'p'::text)
   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.16 rows=2 width=0)
         Index Cond: (letter = 'p'::text)


sample=# EXPLAIN SELECT letter FROM sample WHERE letter = 'd';
                              QUERY PLAN
-----------------------------------------------------------------------
 Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=32)
   Recheck Cond: (letter = 'd'::text)
   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.16 rows=2 width=0)
         Index Cond: (letter = 'd'::text)


sample=# EXPLAIN SELECT letter FROM sample WHERE letter = 'i';
                              QUERY PLAN
-----------------------------------------------------------------------
 Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=32)
   Recheck Cond: (letter = 'i'::text)
   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.16 rows=2 width=0)
         Index Cond: (letter = 'i'::text)
```

### [Running ANALYZE Causes a Sequential Scan for a Common Value]

```sql
sample=# ANALYZE sample;
EXPLAIN SELECT letter FROM sample WHERE letter = 'p';
ANALYZE
                       QUERY PLAN
---------------------------------------------------------
 Seq Scan on sample  (cost=0.00..21.21 rows=342 width=2)
   Filter: (letter = 'p'::text)
```

### [A Less Common Value Causes a Bitmap Index Scan]

```sql
sample=# EXPLAIN SELECT letter FROM sample WHERE letter = 'd';
                              QUERY PLAN
-----------------------------------------------------------------------
 Bitmap Heap Scan on sample  (cost=4.18..14.23 rows=4 width=2)
   Recheck Cond: (letter = 'd'::text)
   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.18 rows=4 width=0)
         Index Cond: (letter = 'd'::text)
```

### [An Even Rarer Value Causes an Index Scan]

```sql
sample=# EXPLAIN SELECT letter FROM sample WHERE letter = 'i';
                              QUERY PLAN
-----------------------------------------------------------------------
 Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=2)
   Recheck Cond: (letter = 'i'::text)
   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.16 rows=2 width=0)
         Index Cond: (letter = 'i'::text)
```

### [Let’s Look at All Values and their Effects]

```sql
sample=# WITH letter (letter, count) AS (SELECT letter, COUNT(*) FROM sample GROUP BY 1) SELECT letter AS l, count, lookup_letter(letter) FROM letter ORDER BY 2 DESC;
 l | count |                               lookup_letter
---+-------+----------------------------------------------------------------------------
 p |   342 | Seq Scan on sample  (cost=0.00..21.21 rows=342 width=2)
 p |   342 |   Filter: (letter = 'p'::text)
 c |    13 | Bitmap Heap Scan on sample  (cost=4.25..20.69 rows=13 width=2)
 c |    13 |   Recheck Cond: (letter = 'c'::text)
 c |    13 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.25 rows=13 width=0)
 c |    13 |         Index Cond: (letter = 'c'::text)
 r |    12 | Bitmap Heap Scan on sample  (cost=4.24..20.14 rows=12 width=2)
 r |    12 |   Recheck Cond: (letter = 'r'::text)
 r |    12 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.24 rows=12 width=0)
 r |    12 |         Index Cond: (letter = 'r'::text)
 f |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 f |     6 |   Recheck Cond: (letter = 'f'::text)
 f |     6 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.19 rows=6 width=0)
 f |     6 |         Index Cond: (letter = 'f'::text)
 l |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 l |     6 |   Recheck Cond: (letter = 'l'::text)
 l |     6 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.19 rows=6 width=0)
 l |     6 |         Index Cond: (letter = 'l'::text)
 t |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 t |     6 |   Recheck Cond: (letter = 't'::text)
 t |     6 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.19 rows=6 width=0)
 t |     6 |         Index Cond: (letter = 't'::text)
 s |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 s |     6 |   Recheck Cond: (letter = 's'::text)
 s |     6 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.19 rows=6 width=0)
 s |     6 |         Index Cond: (letter = 's'::text)
 _ |     5 | Bitmap Heap Scan on sample  (cost=4.19..15.86 rows=5 width=2)
 _ |     5 |   Recheck Cond: (letter = '_'::text)
 _ |     5 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.18 rows=5 width=0)
 _ |     5 |         Index Cond: (letter = '_'::text)
 u |     5 | Bitmap Heap Scan on sample  (cost=4.19..15.86 rows=5 width=2)
 u |     5 |   Recheck Cond: (letter = 'u'::text)
 u |     5 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.18 rows=5 width=0)
 u |     5 |         Index Cond: (letter = 'u'::text)
 d |     4 | Bitmap Heap Scan on sample  (cost=4.18..14.23 rows=4 width=2)
 d |     4 |   Recheck Cond: (letter = 'd'::text)
 d |     4 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.18 rows=4 width=0)
 d |     4 |         Index Cond: (letter = 'd'::text)
 v |     4 | Bitmap Heap Scan on sample  (cost=4.18..14.23 rows=4 width=2)
 v |     4 |   Recheck Cond: (letter = 'v'::text)
 v |     4 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.18 rows=4 width=0)
 v |     4 |         Index Cond: (letter = 'v'::text)
 a |     3 | Bitmap Heap Scan on sample  (cost=4.17..12.31 rows=3 width=2)
 a |     3 |   Recheck Cond: (letter = 'a'::text)
 a |     3 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.17 rows=3 width=0)
 a |     3 |         Index Cond: (letter = 'a'::text)
 e |     2 | Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=2)
 e |     2 |   Recheck Cond: (letter = 'e'::text)
 e |     2 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.16 rows=2 width=0)
 e |     2 |         Index Cond: (letter = 'e'::text)
 i |     2 | Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=2)
 i |     2 |   Recheck Cond: (letter = 'i'::text)
 i |     2 |   ->  Bitmap Index Scan on i_sample  (cost=0.00..4.16 rows=2 width=0)
 i |     2 |         Index Cond: (letter = 'i'::text)
 k |     1 | Index Only Scan using i_sample on sample  (cost=0.15..8.17 rows=1 width=2)
 k |     1 |   Index Cond: (letter = 'k'::text)
```

### [OK, Just the First Lines]

```sql
sample=# WITH letter (letter, count) AS (
sample(# SELECT letter, COUNT(*)
sample(# FROM sample
sample(# GROUP BY 1
sample(# )
sample-# SELECT letter AS l, count,
sample-# (SELECT *
sample(# FROM lookup_letter(letter) AS l2
sample(# LIMIT 1) AS lookup_letter
sample-# FROM letter
sample-# ORDER BY 2 DESC;
 l | count |                               lookup_letter
---+-------+----------------------------------------------------------------------------
 p |   342 | Seq Scan on sample  (cost=0.00..21.21 rows=342 width=2)
 c |    13 | Bitmap Heap Scan on sample  (cost=4.25..20.69 rows=13 width=2)
 r |    12 | Bitmap Heap Scan on sample  (cost=4.24..20.14 rows=12 width=2)
 f |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 l |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 t |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 s |     6 | Bitmap Heap Scan on sample  (cost=4.19..17.25 rows=6 width=2)
 _ |     5 | Bitmap Heap Scan on sample  (cost=4.19..15.86 rows=5 width=2)
 u |     5 | Bitmap Heap Scan on sample  (cost=4.19..15.86 rows=5 width=2)
 d |     4 | Bitmap Heap Scan on sample  (cost=4.18..14.23 rows=4 width=2)
 v |     4 | Bitmap Heap Scan on sample  (cost=4.18..14.23 rows=4 width=2)
 a |     3 | Bitmap Heap Scan on sample  (cost=4.17..12.31 rows=3 width=2)
 e |     2 | Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=2)
 i |     2 | Bitmap Heap Scan on sample  (cost=4.16..10.07 rows=2 width=2)
 k |     1 | Index Only Scan using i_sample on sample  (cost=0.15..8.17 rows=1 width=2)
```

### [We Can Force an Index Scan]

```sql
sample=# SET enable_seqscan = false;
SET enable_bitmapscan = false;
WITH letter (letter, count) AS (SELECT letter, COUNT(*) FROM sample        GROUP BY 1) SELECT letter AS l, count, (SELECT * FROM lookup_letter(letter) AS l2 LIMIT 1) AS lookup_letter FROM letter ORDER BY 2 DESC;
SET
SET
 l | count |                                 lookup_letter
---+-------+-------------------------------------------------------------------------------
 p |   342 | Index Only Scan using i_sample on sample  (cost=0.15..58.03 rows=342 width=2)
 c |    13 | Index Only Scan using i_sample on sample  (cost=0.15..28.98 rows=13 width=2)
 r |    12 | Index Only Scan using i_sample on sample  (cost=0.15..26.67 rows=12 width=2)
 l |     6 | Index Only Scan using i_sample on sample  (cost=0.15..19.70 rows=6 width=2)
 t |     6 | Index Only Scan using i_sample on sample  (cost=0.15..19.70 rows=6 width=2)
 s |     6 | Index Only Scan using i_sample on sample  (cost=0.15..19.70 rows=6 width=2)
 f |     6 | Index Only Scan using i_sample on sample  (cost=0.15..19.70 rows=6 width=2)
 u |     5 | Index Only Scan using i_sample on sample  (cost=0.15..17.39 rows=5 width=2)
 _ |     5 | Index Only Scan using i_sample on sample  (cost=0.15..17.39 rows=5 width=2)
 v |     4 | Index Only Scan using i_sample on sample  (cost=0.15..15.08 rows=4 width=2)
 d |     4 | Index Only Scan using i_sample on sample  (cost=0.15..15.08 rows=4 width=2)
 a |     3 | Index Only Scan using i_sample on sample  (cost=0.15..12.78 rows=3 width=2)
 i |     2 | Index Only Scan using i_sample on sample  (cost=0.15..10.47 rows=2 width=2)
 e |     2 | Index Only Scan using i_sample on sample  (cost=0.15..10.47 rows=2 width=2)
 k |     1 | Index Only Scan using i_sample on sample  (cost=0.15..8.17 rows=1 width=2)

sample=# RESET ALL;
RESET
```

### [What Is in pg_proc.oid?]

```sql
sample=# SELECT oid FROM pg_proc ORDER BY 1 LIMIT 8;
 oid
-----
   3
  31
  33
  34
  35
  38
  39
  40
```

### [Create Temporary Tables from pg_proc and pg_class]

```sql
sample=# CREATE TEMPORARY TABLE sample1 (id, junk) AS SELECT oid, repeat('x', 250) FROM pg_proc ORDER BY random();
CREATE TEMPORARY TABLE sample2 (id, junk) AS SELECT oid, repeat('x', 250) FROM pg_class ORDER BY random();
SELECT 3245
SELECT 424
```

### [Join the Two Tables with a Tight Restriction]

```sql
sample=# EXPLAIN SELECT sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) WHERE sample1.id = 33;
                              QUERY PLAN
----------------------------------------------------------------------
 Nested Loop  (cost=0.00..364.14 rows=770 width=32)
   ->  Seq Scan on sample1  (cost=0.00..313.09 rows=77 width=4)
         Filter: (id = '33'::oid)
   ->  Materialize  (cost=0.00..41.45 rows=10 width=36)
         ->  Seq Scan on sample2  (cost=0.00..41.40 rows=10 width=36)
               Filter: (id = '33'::oid)
```

### [Join the Two Tables with a Looser Restriction]

```sql
sample=# EXPLAIN SELECT sample1.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) WHERE sample2.id > 33;
                              QUERY PLAN
----------------------------------------------------------------------
 Hash Join  (cost=49.86..2189.32 rows=52017 width=32)
   Hash Cond: (sample1.id = sample2.id)
   ->  Seq Scan on sample1  (cost=0.00..274.67 rows=15367 width=36)
   ->  Hash  (cost=41.40..41.40 rows=677 width=4)
         ->  Seq Scan on sample2  (cost=0.00..41.40 rows=677 width=4)
               Filter: (id > '33'::oid)
```

### [Join the Two Tables with No Restriction]

```sql
sample=# EXPLAIN SELECT sample1.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id);
                                QUERY PLAN
--------------------------------------------------------------------------
 Merge Join  (cost=1491.22..3843.32 rows=156129 width=32)
   Merge Cond: (sample2.id = sample1.id)
   ->  Sort  (cost=147.97..153.05 rows=2032 width=4)
         Sort Key: sample2.id
         ->  Seq Scan on sample2  (cost=0.00..36.32 rows=2032 width=4)
   ->  Sort  (cost=1343.26..1381.67 rows=15367 width=36)
         Sort Key: sample1.id
         ->  Seq Scan on sample1  (cost=0.00..274.67 rows=15367 width=36)
```

### [Order of Joined Relations Is Insignificant]

```sql
sample=# EXPLAIN SELECT sample2.junk FROM sample2 JOIN sample1 ON (sample2.id = sample1.id);
                               QUERY PLAN
-------------------------------------------------------------------------
 Merge Join  (cost=1491.22..3843.32 rows=156129 width=32)
   Merge Cond: (sample2.id = sample1.id)
   ->  Sort  (cost=147.97..153.05 rows=2032 width=36)
         Sort Key: sample2.id
         ->  Seq Scan on sample2  (cost=0.00..36.32 rows=2032 width=36)
   ->  Sort  (cost=1343.26..1381.67 rows=15367 width=4)
         Sort Key: sample1.id
         ->  Seq Scan on sample1  (cost=0.00..274.67 rows=15367 width=4)
```

### [Add Optimizer Statistics]

```sql
sample=# ANALYZE sample1;ANALYZE sample2;
ANALYZE
ANALYZE
```

### [This Was a Merge Join without Optimizer Statistics]

```sql
sample=# EXPLAIN SELECT sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id);
                               QUERY PLAN
------------------------------------------------------------------------
 Hash Join  (cost=25.54..195.40 rows=424 width=254)
   Hash Cond: (sample1.id = sample2.id)
   ->  Seq Scan on sample1  (cost=0.00..153.45 rows=3245 width=4)
   ->  Hash  (cost=20.24..20.24 rows=424 width=258)
         ->  Seq Scan on sample2  (cost=0.00..20.24 rows=424 width=258)
```

### [Outer Joins Can Affect Optimizer Join Usage]

```sql
sample=# EXPLAIN SELECT sample1.junk FROM sample1 RIGHT OUTER JOIN sample2 ON (sample1.id = sample2.id);
                              QUERY PLAN
----------------------------------------------------------------------
 Hash Right Join  (cost=25.54..195.40 rows=424 width=254)
   Hash Cond: (sample1.id = sample2.id)
   ->  Seq Scan on sample1  (cost=0.00..153.45 rows=3245 width=258)
   ->  Hash  (cost=20.24..20.24 rows=424 width=4)
         ->  Seq Scan on sample2  (cost=0.00..20.24 rows=424 width=4)
```

### [Cross Joins Are Nested Loop Joins without Join Restriction]

```sql
sample=# EXPLAIN SELECT sample1.junk FROM sample1 CROSS JOIN sample2;
                              QUERY PLAN
----------------------------------------------------------------------
 Nested Loop  (cost=0.00..17373.25 rows=1375880 width=254)
   ->  Seq Scan on sample1  (cost=0.00..153.45 rows=3245 width=254)
   ->  Materialize  (cost=0.00..22.36 rows=424 width=0)
         ->  Seq Scan on sample2  (cost=0.00..20.24 rows=424 width=0)
```

### [Create Indexes]

```sql
sample=# CREATE INDEX i_sample1 on sample1 (id);
CREATE INDEX i_sample2 on sample2 (id);
CREATE INDEX
CREATE INDEX
```

### [Nested Loop with Inner Index Scan Now Possible]

```sql
sample=# EXPLAIN SELECT sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id)WHERE sample1.id = 33;
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Nested Loop  (cost=0.55..16.60 rows=1 width=254)
   ->  Index Only Scan using i_sample1 on sample1  (cost=0.28..8.30 rows=1 width=4)
         Index Cond: (id = '33'::oid)
   ->  Index Scan using i_sample2 on sample2  (cost=0.27..8.29 rows=1 width=258)
         Index Cond: (id = '33'::oid)
```

### [Query Restrictions Affect Join Usage]

```sql
sample=# EXPLAIN SELECT sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) WHERE sample2.junk ~ '^aaa';
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Nested Loop  (cost=0.28..29.61 rows=1 width=254)
   ->  Seq Scan on sample2  (cost=0.00..21.30 rows=1 width=258)
         Filter: (junk ~ '^aaa'::text)
   ->  Index Only Scan using i_sample1 on sample1  (cost=0.28..8.30 rows=1 width=4)
         Index Cond: (id = sample2.id)
```

### [All ’junk’ Columns Begin with ’xxx’]

```sql
sample=# EXPLAIN SELECT sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) WHERE sample2.junk ~ '^xxx';
                               QUERY PLAN
------------------------------------------------------------------------
 Hash Join  (cost=26.60..196.46 rows=424 width=254)
   Hash Cond: (sample1.id = sample2.id)
   ->  Seq Scan on sample1  (cost=0.00..153.45 rows=3245 width=4)
   ->  Hash  (cost=21.30..21.30 rows=424 width=258)
         ->  Seq Scan on sample2  (cost=0.00..21.30 rows=424 width=258)
               Filter: (junk ~ '^xxx'::text)
```

### [Without LIMIT, Hash Is Used for this Unrestricted Join]

```sql
sample=# EXPLAIN SELECT sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) ORDER BY 1;
                                  QUERY PLAN
------------------------------------------------------------------------------
 Sort  (cost=213.90..214.96 rows=424 width=254)
   Sort Key: sample2.junk
   ->  Hash Join  (cost=25.54..195.40 rows=424 width=254)
         Hash Cond: (sample1.id = sample2.id)
         ->  Seq Scan on sample1  (cost=0.00..153.45 rows=3245 width=4)
         ->  Hash  (cost=20.24..20.24 rows=424 width=258)
               ->  Seq Scan on sample2  (cost=0.00..20.24 rows=424 width=258)
```

### [LIMIT Can Affect Join Usage]

```sql
sample=# EXPLAIN SELECT sample2.id, sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) ORDER BY 1 LIMIT 1;
                                        QUERY PLAN
------------------------------------------------------------------------------------------
 Limit  (cost=0.55..2.31 rows=1 width=258)
   ->  Nested Loop  (cost=0.55..745.01 rows=424 width=258)
         ->  Index Scan using i_sample2 on sample2  (cost=0.27..86.63 rows=424 width=258)
         ->  Index Only Scan using i_sample1 on sample1  (cost=0.28..1.54 rows=1 width=4)
               Index Cond: (id = sample2.id)
```

### [LIMIT 10]

```sql
sample=# EXPLAIN SELECT sample2.id, sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) ORDER BY 1 LIMIT 10;
                                        QUERY PLAN
------------------------------------------------------------------------------------------
 Limit  (cost=0.55..18.11 rows=10 width=258)
   ->  Nested Loop  (cost=0.55..745.01 rows=424 width=258)
         ->  Index Scan using i_sample2 on sample2  (cost=0.27..86.63 rows=424 width=258)
         ->  Index Only Scan using i_sample1 on sample1  (cost=0.28..1.54 rows=1 width=4)
               Index Cond: (id = sample2.id)
```

### [LIMIT 100 Switches to Merge Join]

```sql
sample=# EXPLAIN SELECT sample2.id, sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) ORDER BY 1 LIMIT 100;
                                          QUERY PLAN
-----------------------------------------------------------------------------------------------
 Limit  (cost=11.00..167.91 rows=100 width=258)
   ->  Merge Join  (cost=11.00..676.32 rows=424 width=258)
         Merge Cond: (sample1.id = sample2.id)
         ->  Index Only Scan using i_sample1 on sample1  (cost=0.28..576.68 rows=3245 width=4)
         ->  Index Scan using i_sample2 on sample2  (cost=0.27..86.63 rows=424 width=258)
```

### [LIMIT 1000 Switches Back to Hash Join]

```sql
sample=# EXPLAIN SELECT sample2.id, sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) ORDER BY 1 LIMIT 1000;
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Limit  (cost=213.90..214.96 rows=424 width=258)
   ->  Sort  (cost=213.90..214.96 rows=424 width=258)
         Sort Key: sample2.id
         ->  Hash Join  (cost=25.54..195.40 rows=424 width=258)
               Hash Cond: (sample1.id = sample2.id)
               ->  Seq Scan on sample1  (cost=0.00..153.45 rows=3245 width=4)
               ->  Hash  (cost=20.24..20.24 rows=424 width=258)
                     ->  Seq Scan on sample2  (cost=0.00..20.24 rows=424 width=258)
```

### [VACUUM Causes Merge Join Again]

```sql
sample=# VACUUM sample1, sample2;
EXPLAIN SELECT sample2.id, sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) ORDER BY 1 LIMIT 1000;
VACUUM
                                          QUERY PLAN
----------------------------------------------------------------------------------------------
 Limit  (cost=40.82..146.16 rows=424 width=258)
   ->  Merge Join  (cost=40.82..146.16 rows=424 width=258)
         Merge Cond: (sample1.id = sample2.id)
         ->  Index Only Scan using i_sample1 on sample1  (cost=0.28..92.96 rows=3245 width=4)
         ->  Sort  (cost=38.74..39.80 rows=424 width=258)
               Sort Key: sample2.id
               ->  Seq Scan on sample2  (cost=0.00..20.24 rows=424 width=258)
```

### [No LIMIT Was a Hash Join]

```sql
sample=# EXPLAIN SELECT sample2.id, sample2.junk FROM sample1 JOIN sample2 ON (sample1.id = sample2.id) ORDER BY 1;
                                       QUERY PLAN
----------------------------------------------------------------------------------------
 Merge Join  (cost=40.82..146.16 rows=424 width=258)
   Merge Cond: (sample1.id = sample2.id)
   ->  Index Only Scan using i_sample1 on sample1  (cost=0.28..92.96 rows=3245 width=4)
   ->  Sort  (cost=38.74..39.80 rows=424 width=258)
         Sort Key: sample2.id
         ->  Seq Scan on sample2  (cost=0.00..20.24 rows=424 width=258)
```
