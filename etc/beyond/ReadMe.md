# Beyond Joins and Indexes

次の資料で紹介されていたスクリプトを元に partitioning の動作確認を行います。

---

スクリプトの提供元  
https://momjian.us/main/  
スライド  
https://momjian.us/main/writings/pgsql/beyond.pdf

---

### [Setup]

```sql
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF-8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';"
psql -U postgres -p 5432 -d sample
sample=# \pset footer off
sample=# \pset null (null)
Null表示は"(null)"です。
```

### [1. Result]

```sql
sample=# \set EXPLAIN 'EXPLAIN (COSTS OFF)'
sample=# EXPLAIN SELECT 1;
                QUERY PLAN
------------------------------------------
 Result  (cost=0.00..0.01 rows=1 width=4)
```

### [2. Values Scan]

```sql
sample=# EXPLAIN VALUES (1), (2);
                         QUERY PLAN
-------------------------------------------------------------
 Values Scan on "*VALUES*"  (cost=0.00..0.03 rows=2 width=4)
```

### [3. Function Scan]

```sql
sample=# EXPLAIN SELECT * FROM generate_series(1,4);
                             QUERY PLAN
--------------------------------------------------------------------
 Function Scan on generate_series  (cost=0.00..0.04 rows=4 width=4)
```

### [4. Incremental Sort]

```sql
sample=# CREATE TABLE large (x) AS SELECT generate_series(1, 1000000);
ANALYZE large;
CREATE INDEX i_large ON large (x);
ALTER TABLE large ADD COLUMN y INTEGER;
SELECT 1000000
ANALYZE
CREATE INDEX
ALTER TABLE
sample=# EXPLAIN SELECT * FROM large ORDER BY x, y;
                                     QUERY PLAN
-------------------------------------------------------------------------------------
 Incremental Sort  (cost=0.47..75408.43 rows=1000000 width=8)
   Sort Key: x, y
   Presorted Key: x
   ->  Index Scan using i_large on large  (cost=0.42..30408.42 rows=1000000 width=8)
```

### [5. Unique, First Example]

```sql
sample=# EXPLAIN SELECT DISTINCT * FROM generate_series(1, 10) ORDER BY 1;
                                   QUERY PLAN
---------------------------------------------------------------------------------
 Unique  (cost=0.27..0.32 rows=10 width=4)
   ->  Sort  (cost=0.27..0.29 rows=10 width=4)
         Sort Key: generate_series
         ->  Function Scan on generate_series  (cost=0.00..0.10 rows=10 width=4)
```

### [Unique, Second Example]

```sql
sample=# EXPLAIN SELECT 1 UNION SELECT 2;
                         QUERY PLAN
------------------------------------------------------------
 Unique  (cost=0.06..0.07 rows=2 width=4)
   ->  Sort  (cost=0.06..0.07 rows=2 width=4)
         Sort Key: (1)
         ->  Append  (cost=0.00..0.05 rows=2 width=4)
               ->  Result  (cost=0.00..0.01 rows=1 width=4)
               ->  Result  (cost=0.00..0.01 rows=1 width=4)
```

### [6. Append]

```sql
sample=# EXPLAIN SELECT 1 UNION ALL SELECT 2;
                   QUERY PLAN
------------------------------------------------
 Append  (cost=0.00..0.03 rows=2 width=4)
   ->  Result  (cost=0.00..0.01 rows=1 width=4)
   ->  Result  (cost=0.00..0.01 rows=1 width=4)
```

### [7. Merge Append]

```sql
sample=# EXPLAIN (VALUES (1), (2) ORDER BY 1)UNION ALL (VALUES (3), (4) ORDER BY 1) ORDER BY 1;
                                QUERY PLAN
---------------------------------------------------------------------------
 Merge Append  (cost=0.08..0.17 rows=4 width=4)
   Sort Key: "*VALUES*".column1
   ->  Sort  (cost=0.04..0.04 rows=2 width=4)
         Sort Key: "*VALUES*".column1
         ->  Values Scan on "*VALUES*"  (cost=0.00..0.03 rows=2 width=4)
   ->  Sort  (cost=0.04..0.04 rows=2 width=4)
         Sort Key: "*VALUES*_1".column1
         ->  Values Scan on "*VALUES*_1"  (cost=0.00..0.03 rows=2 width=4)
```

### [8, 9. Subquery Scan, HashSetOp]

```sql
sample=# CREATE TABLE small (x) AS SELECT generate_series(1, 1000);
ANALYZE small;
SELECT 1000
ANALYZE
sample=# EXPLAIN SELECT * FROM small EXCEPT SELECT * FROM small;
                                    QUERY PLAN
-----------------------------------------------------------------------------------
 HashSetOp Except  (cost=0.00..65.00 rows=1000 width=8)
   ->  Append  (cost=0.00..60.00 rows=2000 width=8)
         ->  Subquery Scan on "*SELECT* 1"  (cost=0.00..25.00 rows=1000 width=8)
               ->  Seq Scan on small  (cost=0.00..15.00 rows=1000 width=4)
         ->  Subquery Scan on "*SELECT* 2"  (cost=0.00..25.00 rows=1000 width=8)
               ->  Seq Scan on small small_1  (cost=0.00..15.00 rows=1000 width=4)
```

### [10. SetOp]

```sql
sample=# EXPLAIN SELECT * FROM large INTERSECT SELECT * FROM large;
                                          QUERY PLAN
-----------------------------------------------------------------------------------------------
 SetOp Intersect  (cost=336527.69..351527.69 rows=1000000 width=12)
   ->  Sort  (cost=336527.69..341527.69 rows=2000000 width=12)
         Sort Key: "*SELECT* 1".x, "*SELECT* 1".y
         ->  Append  (cost=0.00..58850.00 rows=2000000 width=12)
               ->  Subquery Scan on "*SELECT* 1"  (cost=0.00..24425.00 rows=1000000 width=12)
                     ->  Seq Scan on large  (cost=0.00..14425.00 rows=1000000 width=8)
               ->  Subquery Scan on "*SELECT* 2"  (cost=0.00..24425.00 rows=1000000 width=12)
                     ->  Seq Scan on large large_1  (cost=0.00..14425.00 rows=1000000 width=8)
```

### [11. Materialize]

```sql
sample=# EXPLAIN SELECT * FROM small s1, small s2 WHERE s1.x != s2.x;
                               QUERY PLAN
------------------------------------------------------------------------
 Nested Loop  (cost=0.00..15032.50 rows=999000 width=8)
   Join Filter: (s1.x <> s2.x)
   ->  Seq Scan on small s1  (cost=0.00..15.00 rows=1000 width=4)
   ->  Materialize  (cost=0.00..20.00 rows=1000 width=4)
         ->  Seq Scan on small s2  (cost=0.00..15.00 rows=1000 width=4)
```

### [12. Memoize, Setup]

```sql
sample=# CREATE TABLE small_with_dups (x) AS SELECT generate_series(1, 1000) FROM generate_series(1, 10);
CREATE TABLE medium (x) AS SELECT generate_series(1, 100000);CREATE INDEX i_medium ON medium (x);
ANALYZE;
SELECT 10000
SELECT 100000
CREATE INDEX
ANALYZE

```

### [Memoize]

```sql
sample=# EXPLAIN SELECT * FROM small_with_dups JOIN medium USING (x);
                                       QUERY PLAN
----------------------------------------------------------------------------------------
 Nested Loop  (cost=0.30..815.77 rows=10000 width=4)
   ->  Seq Scan on small_with_dups  (cost=0.00..145.00 rows=10000 width=4)
   ->  Memoize  (cost=0.30..0.43 rows=1 width=4)
         Cache Key: small_with_dups.x
         Cache Mode: logical
         ->  Index Only Scan using i_medium on medium  (cost=0.29..0.42 rows=1 width=4)
               Index Cond: (x = small_with_dups.x)
```

### [13. Group]

```sql
sample=# EXPLAIN SELECT x FROM large WHERE x < 0 GROUP BY x;
                                   QUERY PLAN
--------------------------------------------------------------------------------
 Group  (cost=0.42..4.45 rows=1 width=4)
   Group Key: x
   ->  Index Only Scan using i_large on large  (cost=0.42..4.44 rows=1 width=4)
         Index Cond: (x < 0)
```

### [14. Aggregate]

```sql
sample=# EXPLAIN SELECT COUNT(*) FROM medium;
                             QUERY PLAN
--------------------------------------------------------------------
 Aggregate  (cost=1693.00..1693.01 rows=1 width=8)
   ->  Seq Scan on medium  (cost=0.00..1443.00 rows=100000 width=0)
```

### [15. GroupAggregate]

```sql
sample=# EXPLAIN SELECT x, COUNT(*) FROM medium GROUP BY x ORDER BY x;
                                        QUERY PLAN
------------------------------------------------------------------------------------------
 GroupAggregate  (cost=0.29..4104.29 rows=100000 width=12)
   Group Key: x
   ->  Index Only Scan using i_medium on medium  (cost=0.29..2604.29 rows=100000 width=4)
```

### [16. HashAggregate]

```sql
sample=# EXPLAIN SELECT DISTINCT x FROM medium;
                             QUERY PLAN
--------------------------------------------------------------------
 HashAggregate  (cost=1693.00..2693.00 rows=100000 width=4)
   Group Key: x
   ->  Seq Scan on medium  (cost=0.00..1443.00 rows=100000 width=4)
```

### [17. MixedAggregate]

```sql
sample=# EXPLAIN SELECT x FROM medium GROUP BY ROLLUP(x);
                             QUERY PLAN
--------------------------------------------------------------------
 MixedAggregate  (cost=0.00..2693.01 rows=100001 width=4)
   Hash Key: x
   Group Key: ()
   ->  Seq Scan on medium  (cost=0.00..1443.00 rows=100000 width=4)
```

### [18. WindowAgg]

```sql
sample=# EXPLAIN SELECT x, SUM(x) OVER ()FROM generate_series(1, 10) AS f(x);
                                 QUERY PLAN
-----------------------------------------------------------------------------
 WindowAgg  (cost=0.00..0.23 rows=10 width=12)
   ->  Function Scan on generate_series f  (cost=0.00..0.10 rows=10 width=4)
```

### [19-22. Parallel Seq Scan, Partial Aggregate,

Gather, Finalize Aggregate]

```sql
sample=# EXPLAIN SELECT SUM(x) FROM large;
                                       QUERY PLAN
----------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=10633.55..10633.56 rows=1 width=8)
   ->  Gather  (cost=10633.33..10633.54 rows=2 width=8)
         Workers Planned: 2
         ->  Partial Aggregate  (cost=9633.33..9633.34 rows=1 width=8)
               ->  Parallel Seq Scan on large  (cost=0.00..8591.67 rows=416667 width=4)

```

### [23. Gather Merge]

```sql
sample=# CREATE TABLE huge (x) AS SELECT generate_series(1, 100000000);
ANALYZE huge;
SELECT 100000000
ANALYZE
sample=#
sample=#
sample=# EXPLAIN SELECT * FROM huge ORDER BY 1;
                                     QUERY PLAN
-------------------------------------------------------------------------------------
 Gather Merge  (cost=7842549.89..17565451.01 rows=83333334 width=4)
   Workers Planned: 2
   ->  Sort  (cost=7841549.87..7945716.54 rows=41666667 width=4)
         Sort Key: x
         ->  Parallel Seq Scan on huge  (cost=0.00..859144.67 rows=41666667 width=4)
```

### [24. Parallel Append]

```sql
sample=# EXPLAIN SELECT * FROM huge UNION ALL SELECT * FROM huge ORDER BY 1;
                                            QUERY PLAN
--------------------------------------------------------------------------------------------------
 Gather Merge  (cost=16517422.60..35963224.84 rows=166666668 width=4)
   Workers Planned: 2
   ->  Sort  (cost=16516422.58..16724755.91 rows=83333334 width=4)
         Sort Key: huge.x
         ->  Parallel Append  (cost=0.00..2134956.00 rows=83333334 width=4)
               ->  Parallel Seq Scan on huge  (cost=0.00..859144.67 rows=41666667 width=4)
               ->  Parallel Seq Scan on huge huge_1  (cost=0.00..859144.67 rows=41666667 width=4)
```

### [25, 26. Parallel Hash, Parallel Hash Join]

```sql
sample=# EXPLAIN SELECT * FROM huge h1 JOIN huge h2 USING (x);
                                          QUERY PLAN
----------------------------------------------------------------------------------------------
 Gather  (cost=1543739.00..15356444.47 rows=100000000 width=4)
   Workers Planned: 2
   ->  Parallel Hash Join  (cost=1542739.00..5355444.47 rows=41666667 width=4)
         Hash Cond: (h1.x = h2.x)
         ->  Parallel Seq Scan on huge h1  (cost=0.00..859144.67 rows=41666667 width=4)
         ->  Parallel Hash  (cost=859144.67..859144.67 rows=41666667 width=4)
               ->  Parallel Seq Scan on huge h2  (cost=0.00..859144.67 rows=41666667 width=4)
```

### [27. CTE Scan]

```sql
sample=# EXPLAIN WITH source AS MATERIALIZED (SELECT 1)SELECT * FROM source;
                      QUERY PLAN
------------------------------------------------------
 CTE Scan on source  (cost=0.01..0.03 rows=1 width=4)
   CTE source
     ->  Result  (cost=0.00..0.01 rows=1 width=4)
```

### [28, 29. WorkTable Scan, Recursive Union]

```sql
sample=# EXPLAIN WITH RECURSIVE source (counter) AS (    SELECT 1 UNION ALL    SELECT counter + 1 FROM source    WHERE counter < 10)SELECT * FROM source;
                                    QUERY PLAN
-----------------------------------------------------------------------------------
 CTE Scan on source  (cost=2.95..3.57 rows=31 width=4)
   CTE source
     ->  Recursive Union  (cost=0.00..2.95 rows=31 width=4)
           ->  Result  (cost=0.00..0.01 rows=1 width=4)
           ->  WorkTable Scan on source source_1  (cost=0.00..0.23 rows=3 width=4)
                 Filter: (counter < 10)
```

### [30. ProjectSet]

```sql
sample=# EXPLAIN SELECT generate_series(1,4);
                   QUERY PLAN
------------------------------------------------
 ProjectSet  (cost=0.00..0.04 rows=4 width=4)
   ->  Result  (cost=0.00..0.01 rows=1 width=0)
```

### [31. LockRows]

```sql
sample=# EXPLAIN SELECT * FROM small FOR UPDATE;
                           QUERY PLAN
----------------------------------------------------------------
 LockRows  (cost=0.00..25.00 rows=1000 width=10)
   ->  Seq Scan on small  (cost=0.00..15.00 rows=1000 width=10)
```

### [32. Sample Scan]

```sql
sample=# EXPLAIN SELECT * FROM small TABLESAMPLE SYSTEM(50);
                        QUERY PLAN
-----------------------------------------------------------
 Sample Scan on small  (cost=0.00..13.00 rows=500 width=4)
   Sampling: system ('50'::real)
```

### [33. Table Function Scan]

```sql
sample=# EXPLAIN SELECT * FROM XMLTABLE('/ROWS/ROW'
PASSING
$$
<ROWS>
    <ROW id="1">
        <COUNTRY_ID>US</COUNTRY_ID>
    </ROW>
</ROWS>
$$
COLUMNS id int PATH '@id',_id FOR ORDINALITY);
                              QUERY PLAN
-----------------------------------------------------------------------
 Table Function Scan on "xmltable"  (cost=0.00..1.00 rows=100 width=8)

```

### [34. Foreign Scan]

```sql
sample=# CREATE EXTENSION postgres_fdw;
CREATE SERVER postgres_fdw_test FOREIGN DATA WRAPPER
postgres_fdw OPTIONS (host 'localhost', dbname 'fdw_test');CREATE USER MAPPING FOR PUBLIC SERVER postgres_fdw_test OPTIONS (password '');
CREATE FOREIGN TABLE other_world (greeting TEXT) SERVER postgres_fdw_test OPTIONS (table_name 'world');
CREATE EXTENSION
CREATE SERVER
CREATE USER MAPPING
CREATE FOREIGN TABLE
sample=# EXPLAIN SELECT * FROM other_world;
                              QUERY PLAN
-----------------------------------------------------------------------
 Foreign Scan on other_world  (cost=100.00..153.86 rows=1462 width=32)

```

### [35. Tid Scan]

```sql
sample=# EXPLAIN SELECT * FROM small WHERE ctid = '(0,1)';
                     QUERY PLAN
-----------------------------------------------------
 Tid Scan on small  (cost=0.00..4.01 rows=1 width=4)
   TID Cond: (ctid = '(0,1)'::tid)

```

### [36. Insert]

```sql
sample=# EXPLAIN INSERT INTO small VALUES (0);
                    QUERY PLAN
---------------------------------------------------
 Insert on small  (cost=0.00..0.01 rows=0 width=0)
   ->  Result  (cost=0.00..0.01 rows=1 width=4)

```

### [37. Update]

```sql
sample=# EXPLAIN UPDATE small SET x = 1 WHERE x = 0;
                         QUERY PLAN
-------------------------------------------------------------
 Update on small  (cost=0.00..17.50 rows=0 width=0)
   ->  Seq Scan on small  (cost=0.00..17.50 rows=1 width=10)
         Filter: (x = 0)

```

### [38. Delete]

```sql
sample=# EXPLAIN DELETE FROM small;
                          QUERY PLAN
---------------------------------------------------------------
 Delete on small  (cost=0.00..15.00 rows=0 width=0)
   ->  Seq Scan on small  (cost=0.00..15.00 rows=1000 width=6)


sample=# EXPLAIN TRUNCATE small;
ERROR:  "TRUNCATE"またはその近辺で構文エラー
行 1: EXPLAIN TRUNCATE small;
```

### [39. Merge]

```sql
sample=# CREATE TABLE mergetest (x, y) AS VALUES (1, NULL), (3, NULL), (5, NULL);
SELECT 3
sample=# EXPLAIN MERGE INTO mergetest USING (VALUES (1), (2), (3), (4), (5), (6)) m (x) ON mergetest.x = m.x WHEN NOT MATCHED THEN     INSERT (x) VALUES (m.x)WHEN MATCHED THEN     UPDATE SET y = TRUE;
                                  QUERY PLAN
-------------------------------------------------------------------------------
 Merge on mergetest  (cost=0.15..27.99 rows=0 width=0)
   ->  Hash Right Join  (cost=0.15..27.99 rows=38 width=10)
         Hash Cond: (mergetest.x = "*VALUES*".column1)
         ->  Seq Scan on mergetest  (cost=0.00..22.70 rows=1270 width=10)
         ->  Hash  (cost=0.08..0.08 rows=6 width=4)
               ->  Values Scan on "*VALUES*"  (cost=0.00..0.08 rows=6 width=4)

```

### [40. Semi Join, First Example]

```sql
sample=# EXPLAIN SELECT * FROM small WHERE EXISTS (SELECT * FROM medium WHERE medium.x = small.x);
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Nested Loop Semi Join  (cost=0.29..1439.00 rows=1000 width=4)
   ->  Seq Scan on small  (cost=0.00..15.00 rows=1000 width=4)
   ->  Index Only Scan using i_medium on medium  (cost=0.29..1.41 rows=1 width=4)
         Index Cond: (x = small.x)

sample=# EXPLAIN SELECT * FROM small WHERE small.x IN (SELECT medium.x FROM medium);
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Nested Loop Semi Join  (cost=0.29..1439.00 rows=1000 width=4)
   ->  Seq Scan on small  (cost=0.00..15.00 rows=1000 width=4)
   ->  Index Only Scan using i_medium on medium  (cost=0.29..1.41 rows=1 width=4)
         Index Cond: (x = small.x)
```

### [41. Anti Join]

```sql
sample=# EXPLAIN SELECT * FROM medium WHERE NOT EXISTS (SELECT * FROM small WHERE small.x = medium.x);
                             QUERY PLAN
---------------------------------------------------------------------
 Hash Anti Join  (cost=27.50..2724.13 rows=99000 width=4)
   Hash Cond: (medium.x = small.x)
   ->  Seq Scan on medium  (cost=0.00..1443.00 rows=100000 width=4)
   ->  Hash  (cost=15.00..15.00 rows=1000 width=4)
         ->  Seq Scan on small  (cost=0.00..15.00 rows=1000 width=4)
```

### [42. SubPlan]

```sql
sample=# EXPLAIN SELECT * FROM small WHERE small.x NOT IN (SELECT medium.x FROM medium);
                              QUERY PLAN
----------------------------------------------------------------------
 Seq Scan on small  (cost=1693.00..1710.50 rows=500 width=4)
   Filter: (NOT (hashed SubPlan 1))
   SubPlan 1
     ->  Seq Scan on medium  (cost=0.00..1443.00 rows=100000 width=4)

```

### [43. Others: Outer Join Remova]

```sql
sample=# CREATE UNIQUE INDEX i_small ON small (x);
CREATE INDEX
sample=# EXPLAIN SELECT medium.x FROM medium LEFT JOIN small USING (x);
                          QUERY PLAN
--------------------------------------------------------------
 Seq Scan on medium  (cost=0.00..1443.00 rows=100000 width=4)
```
