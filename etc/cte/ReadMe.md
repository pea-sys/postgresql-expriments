# Common Table Expressions

次の資料で紹介されていたスクリプトを元に cte の動作確認を行います。

---

スクリプトの提供元  
https://momjian.us/main/  
スライド  
https://momjian.us/main/writings/pgsql/cte.pdf

---

### [Setup]

```sql
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF-8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';"
psql -U postgres -p 5432 -d sample
sample=# \pset footer off
sample=# \pset null (null)
Null表示は"(null)"です。
```

### [Declarative]

```sql
sample=# SELECT 'Hello'UNION ALL SELECT 'Hello'UNION ALL SELECT 'Hello'UNION ALL SELECT 'Hello';
 ?column?
----------
 Hello
 Hello
 Hello
 Hello
```

### [A Simple CTE]

```sql
sample=# WITH source AS ( SELECT 1)
SELECT * FROM source;
 ?column?
----------
        1
```

### [Let’s Name the Returned CTE Column]

```sql
sample=# WITH source AS (SELECT 1 AS col1)
SELECT * FROM source;
 col1
------
    1
```

### [The Column Can Also Be Named in the WITH Clause]

```sql
sample=# WITH source (col1) AS ( SELECT 1)
SELECT * FROM source;
 col1
------
    1
```

### [Columns Can Be Renamed]

```sql
sample=# WITH source (col2) AS (SELECT 1 AS col1)
SELECT col2 AS col3 FROM source;
 col3
------
    1
```

### [Multiple CTE Columns Can Be Returned]

```sql
sample=# WITH source AS (SELECT 1, 2)
SELECT * FROM source;
 ?column? | ?column?
----------+----------
        1 |        2
```

### [UNION Refresher]

```sql
sample=# SELECT 1 UNION SELECT 1;
SELECT 1 UNION ALL SELECT 1;
 ?column?
----------
        1


 ?column?
----------
        1
        1
```

### [Possible To Create Multiple CTE Results]

```sql
sample=# WITH source AS (SELECT 1, 2), source2 AS (SELECT 3, 4)
SELECT * FROM source UNION ALL SELECT * FROM source2;
 ?column? | ?column?
----------+----------
        1 |        2
        3 |        4
```

### [CTE with Real Tables]

```sql
sample=# WITH source AS (SELECT lanname, rolname FROM pg_language JOIN pg_roles ON lanowner = pg_roles.oid)
SELECT * FROM source;
 lanname  | rolname
----------+----------
 internal | postgres
 c        | postgres
 sql      | postgres
 plpgsql  | postgres
```

### [CTE Can Be Processed More than Once]

```sql
sample=# WITH source AS (SELECT lanname, rolname FROM pg_language JOIN pg_roles ON lanowner = pg_roles.oid        ORDER BY lanname)
SELECT * FROM source UNION ALL SELECT MIN(lanname), NULL FROM source;
 lanname  | rolname
----------+----------
 c        | postgres
 internal | postgres
 plpgsql  | postgres
 sql      | postgres
 c        | (null)
```

### [CTE Can Be Joined]

```sql
sample=# WITH class AS (SELECT oid, relname FROM pg_class WHERE relkind = 'r')SELECT class.relname, attname FROM pg_attribute, class WHERE class.oid = attrelid ORDER BY 1, 2 LIMIT 5;
   relname    |    attname
--------------+----------------
 pg_aggregate | aggcombinefn
 pg_aggregate | aggdeserialfn
 pg_aggregate | aggfinalextra
 pg_aggregate | aggfinalfn
 pg_aggregate | aggfinalmodify
```

### [Looping]

```sql
sample=# WITH RECURSIVE source AS (SELECT 1)
SELECT * FROM source;
 ?column?
----------
        1
```

### [This Is an Infinite Loop]

```sql
sample=# SET statement_timeout = '1s';
WITH RECURSIVE source AS (SELECT 1 UNION ALL SELECT 1 FROM  source)
SELECT * FROM source;
SET
ERROR:  ステートメントのタイムアウトのためステートメントをキャンセルしています
```

### [The ’Hello’ Example in SQL]

```sql
sample=# WITH RECURSIVE source AS ( SELECT 'Hello'        UNION ALL SELECT 'Hello' FROM source)
SELECT * FROM source;
RESET statement_timeout;
ERROR:  ステートメントのタイムアウトのためステートメントをキャンセルしています
RESET
```

### [UNION without ALL Avoids Recursion]

```sql
sample=# WITH RECURSIVE source AS (SELECT 'Hello' UNION  SELECT 'Hello' FROM source)
SELECT * FROM source;
 ?column?
----------
 Hello
```

### [CTEs Are Useful When Loops Are Constrained]

```sql
sample=# WITH RECURSIVE source (counter) AS ( SELECT 1 UNION ALL SELECT counter + 1 FROM source WHERE counter < 10)
SELECT * FROM source;
 counter
---------
       1
       2
       3
       4
       5
       6
       7
       8
       9
      10
```

### [Ten Factorial Using CTE]

```sql
sample=# WITH RECURSIVE source (counter, product) AS (SELECT 1, 1 UNION ALL SELECT counter + 1, product * (counter + 1) FROM source WHERE counter < 10)SELECT counter, product FROM source;
 counter | product
---------+---------
       1 |       1
       2 |       2
       3 |       6
       4 |      24
       5 |     120
       6 |     720
       7 |    5040
       8 |   40320
       9 |  362880
      10 | 3628800
```

### [Only Display the Desired Row]

```sql
sample=# WITH RECURSIVE source (counter, product) AS ( SELECT 1, 1 UNION ALL SELECT counter + 1, product * (counter + 1) FROM source WHERE counter < 10)
SELECT counter, product FROM source WHERE counter = 10;
 counter | product
---------+---------
      10 | 3628800

```

### [String Manipulation Is Also Possible]

```sql
sample=# WITH RECURSIVE source (str) AS (SELECT 'a'        UNION ALL SELECT str || 'a' FROM source WHERE length(str) < 10)
SELECT * FROM source;
    str
------------
 a
 aa
 aaa
 aaaa
 aaaaa
 aaaaaa
 aaaaaaa
 aaaaaaaa
 aaaaaaaaa
 aaaaaaaaaa
```

### [Characters Can Be Computed]

```sql
sample=# WITH RECURSIVE source (str) AS (SELECT 'a'        UNION ALL SELECT str || chr(ascii(right(str, 1)) + 1)        FROM source WHERE length(str) < 10)SELECT * FROM source;
    str
------------
 a
 ab
 abc
 abcd
 abcde
 abcdef
 abcdefg
 abcdefgh
 abcdefghi
 abcdefghij
```

### [ASCII Art Is Even Possible]

```sql
sample=# WITH RECURSIVE source (counter) AS ( SELECT -10  UNION ALL SELECT counter + 1  FROM source  WHERE counter < 10) SELECT  repeat(' ', 5 - abs(counter) / 2) ||'X' || repeat(' ', abs(counter)) || 'X' FROM source;
   ?column?
--------------
 X          X
  X         X
  X        X
   X       X
   X      X
    X     X
    X    X
     X   X
     X  X
      X X
      XX
      X X
     X  X
     X   X
    X    X
    X     X
   X      X
   X       X
  X        X
  X         X
 X          X
```

### [How Is that Done?]

```sql
sample=# WITH RECURSIVE source (counter) AS (  SELECT -10 UNION ALL SELECT counter + 1  FROM source  WHERE counter < 10)SELECT  counter,  repeat(' ', 5 - abs(counter) / 2) || 'X' || repeat(' ', abs(counter)) || 'X'FROM source;
 counter |   ?column?
---------+--------------
     -10 | X          X
      -9 |  X         X
      -8 |  X        X
      -7 |   X       X
      -6 |   X      X
      -5 |    X     X
      -4 |    X    X
      -3 |     X   X
      -2 |     X  X
      -1 |      X X
       0 |      XX
       1 |      X X
       2 |     X  X
       3 |     X   X
       4 |    X    X
       5 |    X     X
       6 |   X      X
       7 |   X       X
       8 |  X        X
       9 |  X         X
      10 | X          X
```

### [ASCII Diamonds Are Even Possible]

```sql
sample=# WITH RECURSIVE source (counter) AS (SELECT -10  UNION ALL  SELECT counter + 1 FROM source        WHERE counter < 10)SELECT  repeat(' ', abs(counter)/2) ||        'X' || repeat(' ', 10 - abs(counter)) || 'X'FROM source;
   ?column?
--------------
      XX
     X X
     X  X
    X   X
    X    X
   X     X
   X      X
  X       X
  X        X
 X         X
 X          X
 X         X
  X        X
  X       X
   X      X
   X     X
    X    X
    X   X
     X  X
     X X
      XX
```

### [More Rounded]

```sql
sample=# WITH RECURSIVE source (counter) AS ( SELECT -10 UNION ALL   SELECT counter + 1  FROM source        WHERE counter < 10)SELECT  repeat(' ', int4(pow(counter, 2)/10)) ||  'X' ||  repeat(' ', 2 * (10 - int4(pow(counter, 2)/10))) ||  'X'FROM source;
        ?column?
------------------------
           XX
         X    X
       X        X
      X          X
     X            X
   X                X
   X                X
  X                  X
 X                    X
 X                    X
 X                    X
 X                    X
 X                    X
  X                  X
   X                X
   X                X
     X            X
      X          X
       X        X
         X    X
           XX
```

### [A Real Circle]

```sql
sample=# WITH RECURSIVE source (counter) AS ( SELECT -10 UNION ALL SELECT counter + 1  FROM source WHERE counter < 10)SELECT  repeat(' ', int4(pow(counter, 2)/5)) || 'X' ||   repeat(' ', 2 * (20 - int4(pow(counter, 2)/5))) || 'X'FROM source;
                  ?column?
--------------------------------------------
                     XX
                 X        X
              X              X
           X                    X
        X                          X
      X                              X
    X                                  X
   X                                    X
  X                                      X
 X                                        X
 X                                        X
 X                                        X
  X                                      X
   X                                    X
    X                                  X
      X                              X
        X                          X
           X                    X
              X              X
                 X        X
                     XX
```

### [Prime Factorization in SQL]

```sql
sample=# WITH RECURSIVE source (counter, factor, is_factor) AS ( SELECT 2, 56, false  UNION ALL SELECT  CASE  WHEN factor % counter = 0 THEN counter ELSE counter + 1
 END,
 CASE  WHEN factor % counter = 0 THEN factor / counter    ELSE factor
 END,
 CASE WHEN factor % counter = 0 THEN true
 ELSE false
 END
 FROM source WHERE factor <> 1)SELECT * FROM source;
 counter | factor | is_factor
---------+--------+-----------
       2 |     56 | f
       2 |     28 | t
       2 |     14 | t
       2 |      7 | t
       3 |      7 | f
       4 |      7 | f
       5 |      7 | f
       6 |      7 | f
       7 |      7 | f
       7 |      1 | t
```

### [Only Return Prime Factors]

```sql
sample=# WITH RECURSIVE source (counter, factor, is_factor) AS ( SELECT 2, 56, false  UNION ALL
SELECT CASE WHEN factor % counter = 0 THEN counter        ELSE counter + 1
END,
CASE WHEN factor % counter = 0 THEN factor / counter         ELSE factor
END,
CASE WHEN factor % counter = 0 THEN true
ELSE false
END
FROM source  WHERE factor <> 1)SELECT * FROM source WHERE is_factor;
 counter | factor | is_factor
---------+--------+-----------
       2 |     28 | t
       2 |     14 | t
       2 |      7 | t
       7 |      1 | t
```

### [Factors of 322434]

```sql
sample=# WITH RECURSIVE source (counter, factor, is_factor) AS ( SELECT 2, 322434, false UNION ALL SELECT  CASE  WHEN factor % counter = 0 THEN counter ELSE counter + 1   END,   CASE  WHEN factor % counter = 0 THEN factor / counter  ELSE factor  END,  CASE  WHEN factor % counter = 0 THEN true   ELSE false  END  FROM source  WHERE factor <> 1)SELECT * FROM source WHERE is_factor;
 counter | factor | is_factor
---------+--------+-----------
       2 | 161217 | t
       3 |  53739 | t
       3 |  17913 | t
       3 |   5971 | t
       7 |    853 | t
     853 |      1 | t
```

### [Prime Factors of 66]

```sql
sample=# WITH RECURSIVE source (counter, factor, is_factor) AS ( SELECT 2, 66, false UNION ALL SELECT  CASE   WHEN factor % counter = 0 THEN counter ELSE counter + 1  END,  CASE  WHEN factor % counter = 0 THEN factor / counter  ELSE factor                END,  CASE  WHEN factor % counter = 0 THEN true  ELSE false  END        FROM source  WHERE factor <> 1)SELECT * FROM source;
 counter | factor | is_factor
---------+--------+-----------
       2 |     66 | f
       2 |     33 | t
       3 |     33 | f
       3 |     11 | t
       4 |     11 | f
       5 |     11 | f
       6 |     11 | f
       7 |     11 | f
       8 |     11 | f
       9 |     11 | f
      10 |     11 | f
      11 |     11 | f
      11 |      1 | t
```

### [Skip Evens >2, Exit Early with a Final Prime]

```sql
sample=# WITH RECURSIVE source (counter, factor, is_factor) AS ( SELECT 2, 66, false
UNION ALL
SELECT CASE WHEN factor % counter = 0 THEN counter
WHEN counter * counter > factor THEN factor
WHEN counter = 2 THEN 3 ELSE counter + 2
END,
CASE  WHEN factor % counter = 0 THEN factor / counter
ELSE factor
END,
CASE  WHEN factor % counter = 0 THEN true
ELSE false
END
FROM source  WHERE factor <> 1)
SELECT * FROM source;
 counter | factor | is_factor
---------+--------+-----------
       2 |     66 | f
       2 |     33 | t
       3 |     33 | f
       3 |     11 | t
       5 |     11 | f
      11 |     11 | f
      11 |      1 | t
```

### [Return Only Prime Factors]

```sql
sample=# WITH RECURSIVE source (counter, factor, is_factor) AS (  SELECT 2,66, false
UNION ALL SELECT  CASE                        WHEN factor % counter = 0 THEN counter   WHEN counter * counter > factor THEN factor  WHEN counter = 2 THEN 3
ELSE counter + 2
END,
CASE WHEN factor % counter = 0 THEN factor / counter ELSE factor
END,
CASE WHEN factor % counter = 0 THEN true
ELSE false
END
FROM source WHERE factor <> 1)SELECT * FROM source WHERE is_factor;
 counter | factor | is_factor
---------+--------+-----------
       2 |     33 | t
       3 |     11 | t
      11 |      1 | t
(3 行)
```

### [Recursive Table Processing: Setup]

```sql
sample=# CREATE TEMPORARY TABLE part (parent_part_no INTEGER, part_no INTEGER);INSERT INTO part VALUES (1, 11);
INSERT INTO part VALUES (1, 12);
INSERT INTO part VALUES (1, 13);
INSERT INTO part VALUES (2, 21);
INSERT INTO part VALUES (2, 22);
INSERT INTO part VALUES (2, 23);
INSERT INTO part VALUES (11, 101);
INSERT INTO part VALUES (13, 102);
INSERT INTO part VALUES (13, 103);
INSERT INTO part VALUES (22, 221);
INSERT INTO part VALUES (22, 222);
INSERT INTO part VALUES (23, 231);
CREATE TABLE
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
INSERT 0 1
```

### [Use CTEs To Walk Through Parts Heirarchy]

```sql
sample=# WITH RECURSIVE source (part_no) AS (SELECT 2 UNION ALL SELECT part.part_no FROM source JOIN part ON (source.part_no = part.parent_part_no))
SELECT * FROM source;
 part_no
---------
       2
      21
      22
      23
     221
     222
     231
```

### [Add Dashes]

```sql
sample=# WITH RECURSIVE source (level, part_no) AS ( SELECT 0, 2 UNION ALL  SELECT level + 1, part.part_no  FROM source JOIN part ON (source.part_no = part.parent_part_no))
SELECT '+' || repeat('-', level * 2) || part_no::text AS part_tree FROM source;
 part_tree
-----------
 +2
 +--21
 +--22
 +--23
 +----221
 +----222
 +----231
```

### [The Parts in ASCII Order]

```sql
sample=# WITH RECURSIVE source (level, tree, part_no) AS (SELECT 0, '2', 2 UNION ALL SELECT level + 1, tree || ' ' || part.part_no::text, part.part_noFROM source JOIN part ON (source.part_no = part.parent_part_no))
SELECT '+' || repeat('-', level * 2) || part_no::text AS part_tree, tree FROM source ORDER BY tree;
 part_tree |   tree
-----------+----------
 +2        | 2
 +--21     | 2 21
 +--22     | 2 22
 +----221  | 2 22 221
 +----222  | 2 22 222
 +--23     | 2 23
 +----231  | 2 23 231
```

### [The Parts in Numeric Order]

```sql
sample=# WITH RECURSIVE source (level, tree, part_no) AS (  SELECT 0, '{2}'::int[], 2  UNION ALL  SELECT level + 1, array_append(tree, part.part_no), part.part_no FROM source JOIN part ON (source.part_no = part.parent_part_no))SELECT '+' || repeat('-', level * 2) || part_no::text AS part_tree, tree FROM source ORDER BY tree;
 part_tree |    tree
-----------+------------
 +2        | {2}
 +--21     | {2,21}
 +--22     | {2,22}
 +----221  | {2,22,221}
 +----222  | {2,22,222}
 +--23     | {2,23}
 +----231  | {2,23,231}
```

### [Full Output]

```sql
sample=# WITH RECURSIVE source (level, tree, part_no) AS (SELECT 0, '{2}'::int[], 2  UNION ALL SELECT level + 1, array_append(tree, part.part_no), part.part_no FROM source JOIN part ON (source.part_no = part.parent_part_no))
SELECT *, '+' || repeat('-', level * 2) || part_no::text AS part_tree FROM source ORDER BY tree;
 level |    tree    | part_no | part_tree
-------+------------+---------+-----------
     0 | {2}        |       2 | +2
     1 | {2,21}     |      21 | +--21
     1 | {2,22}     |      22 | +--22
     2 | {2,22,221} |     221 | +----221
     2 | {2,22,222} |     222 | +----222
     1 | {2,23}     |      23 | +--23
     2 | {2,23,231} |     231 | +----231
```

### [CTE for SQL Object Dependency]

```sql
sample=# CREATE TEMPORARY TABLE deptest (x1 INTEGER);
CREATE TABLE
sample=# WITH RECURSIVE dep (classid, obj) AS (        SELECT (SELECT oid FROM pg_class WHERE relname = 'pg_class'),   oid  FROM pg_class  WHERE relname = 'deptest' UNION ALL  SELECT pg_depend.classid, objid  FROM pg_depend JOIN dep ON (refobjid = dep.obj))SELECT  (SELECT relname FROM pg_class WHERE oid = classid) AS class,  (SELECT typname FROM pg_type WHERE oid = obj) AS type,        (SELECT relname FROM pg_class WHERE oid = obj) AS class, (SELECT relkind FROM pg_class where oid = obj::regclass) AS kind, (SELECT pg_get_expr(adbin, classid) FROM pg_attrdef WHERE oid = obj) AS attrdef, (SELECT conname FROM pg_constraint WHERE oid = obj) AS constraint FROM dep ORDER BY obj;
  class   |   type   |  class  | kind | attrdef | constraint
----------+----------+---------+------+---------+------------
 pg_class |          | deptest | r    |         |
 pg_type  | _deptest |         |      |         |
 pg_type  | deptest  |         |      |         |
```

### [Do Not Show deptest]

```sql
sample=# WITH RECURSIVE dep (classid, obj) AS (        SELECT classid, objid  FROM pg_depend JOIN pg_class ON (refobjid = pg_class.oid)  WHERE relname = 'deptest'        UNION ALL  SELECT pg_depend.classid, objid   FROM pg_depend JOIN dep ON (refobjid = dep.obj))SELECT  (SELECT relname FROM pg_class WHERE oid = classid) AS class,        (SELECT typname FROM pg_type WHERE oid = obj) AS type, (SELECT relname FROM pg_class WHERE oid = obj) AS class,  (SELECT relkind FROM pg_class where oid = obj::regclass) AS kind, (SELECT pg_get_expr(adbin, classid) FROM pg_attrdef WHERE oid = obj) AS attrdef,  (SELECT conname FROM pg_constraint WHERE oid = obj) AS constraint FROM dep ORDER BY obj;
  class  |   type   | class  |  kind  | attrdef | constraint
---------+----------+--------+--------+---------+------------
 pg_type | _deptest | (null) | (null) | (null)  | (null)
 pg_type | deptest  | (null) | (null) | (null)  | (null)
```

### [Add a Primary Key]

```sql
sample=# ALTER TABLE deptest ADD PRIMARY KEY (x1);

WITH RECURSIVE dep (classid, obj) AS (SELECT (SELECT oid FROM pg_class WHERE relname = 'pg_class'), oid FROM pg_class WHERE relname = 'deptest'  UNION ALL SELECT pg_depend.classid, objid  FROM pg_depend JOIN dep ON (refobjid = dep.obj))

SELECT  (SELECT relname FROM pg_class WHERE oid = classid) AS class, (SELECT typname FROM pg_type WHERE oid = obj) AS type, (SELECT relname FROM pg_class WHERE oid = obj) AS class, (SELECT relkind FROM pg_class where oid = obj::regclass) AS kind, (SELECT pg_get_expr(adbin, classid) FROM pg_attrdef WHERE oid = obj) AS attrdef,  (SELECT conname FROM pg_constraint WHERE oid = obj) AS constraint FROM dep ORDER BY obj;
ALTER TABLE
     class     |   type   |    class     |  kind  | attrdef |  constraint
---------------+----------+--------------+--------+---------+--------------
 pg_class      | (null)   | deptest      | r      | (null)  | (null)
 pg_type       | _deptest | (null)       | (null) | (null)  | (null)
 pg_type       | deptest  | (null)       | (null) | (null)  | (null)
 pg_class      | (null)   | deptest_pkey | i      | (null)  | (null)
 pg_constraint | (null)   | (null)       | (null) | (null)  | deptest_pkey
```

### [Add a SERIAL Column]

```sql
sample=# ALTER TABLE deptest ADD COLUMN x2 SERIAL;
WITH RECURSIVE dep (classid, obj) AS (SELECT (SELECT oid FROM pg_class WHERE relname = 'pg_class'),  oid   FROM pg_class   WHERE relname = 'deptest' UNION ALL  SELECT pg_depend.classid, objid   FROM pg_depend JOIN dep ON (refobjid = dep.obj))

SELECT  (SELECT relname FROM pg_class WHERE oid = classid) AS class,  (SELECT typname FROM pg_type WHERE oid = obj) AS type, (SELECT relname FROM pg_class WHERE oid = obj) AS class,  (SELECT relkind FROM pg_class where oid = obj::regclass) AS kind,  (SELECT pg_get_expr(adbin, classid) FROM pg_attrdef WHERE oid = obj) AS attrdef  FROM dep ORDER BY obj;
ALTER TABLE
     class     |   type   |     class      |  kind  |               attrdef
---------------+----------+----------------+--------+-------------------------------------
 pg_class      | (null)   | deptest        | r      | (null)
 pg_type       | _deptest | (null)         | (null) | (null)
 pg_type       | deptest  | (null)         | (null) | (null)
 pg_class      | (null)   | deptest_pkey   | i      | (null)
 pg_constraint | (null)   | (null)         | (null) | (null)
 pg_class      | (null)   | deptest_x2_seq | S      | (null)
 pg_attrdef    | (null)   | (null)         | (null) | nextval('deptest_x2_seq'::regclass)
 pg_attrdef    | (null)   | (null)         | (null) | nextval('deptest_x2_seq'::regclass)
```

### [Show Full Output]

```sql
sample=# WITH RECURSIVE dep (level, tree, classid, obj) AS (SELECT 0, array_append(null, oid)::oid[], (SELECT oid FROM pg_class WHERE relname = 'pg_class'),  oid  FROM pg_class  WHERE relname = 'deptest'  UNION ALL SELECT level + 1, array_append(tree, objid),  pg_depend.classid, objid        FROM pg_depend JOIN dep ON (refobjid = dep.obj))

SELECT  tree,  (SELECT relname FROM pg_class WHERE oid = classid) AS class,   (SELECT typname FROM pg_type WHERE oid = obj) AS type, (SELECT relname FROM pg_class WHERE oid = obj) AS class, (SELECT pg_get_expr(adbin, classid) FROM pg_attrdef WHERE oid = obj) AS attrdef  FROM dep ORDER BY tree, obj;
        tree         |     class     |   type   |     class      |               attrdef
---------------------+---------------+----------+----------------+-------------------------------------
 {18596}             | pg_class      | (null)   | deptest        | (null)
 {18596,18598}       | pg_type       | deptest  | (null)         | (null)
 {18596,18598,18597} | pg_type       | _deptest | (null)         | (null)
 {18596,18600}       | pg_constraint | (null)   | (null)         | (null)
 {18596,18600,18599} | pg_class      | (null)   | deptest_pkey   | (null)
 {18596,18601}       | pg_class      | (null)   | deptest_x2_seq | (null)
 {18596,18601,18602} | pg_attrdef    | (null)   | (null)         | nextval('deptest_x2_seq'::regclass)
 {18596,18602}       | pg_attrdef    | (null)   | (null)         | nextval('deptest_x2_seq'::regclass)
```

### [Use INSERT, UPDATE, DELETE in WITH Clauses]

```sql
sample=# CREATE TEMPORARY TABLE retdemo (x NUMERIC);
INSERT INTO retdemo VALUES (random()), (random()), (random()) RETURNING x;

WITH source AS (INSERT INTO retdemo VALUES (random()), (random()), (random()) RETURNING x)SELECT AVG(x) FROM source;
CREATE TABLE
         x
--------------------
  0.603149390469082
  0.376445212377874
 0.0295894307148006


INSERT 0 3
          avg
------------------------
 0.58103297357492866667
```

### [Supply Rows to INSERT, UPDATE, DELETE Using WITH Clauses]

```sql
sample=# WITH source AS (DELETE FROM retdemo RETURNING x)SELECT MAX(x) FROM source;
       max
------------------
 0.84672475189578
```

### Supply Rows to INSERT, UPDATE, DELETE Using WITH Clauses

```sql
sample=# CREATE TEMPORARY TABLE retdemo2 (x NUMERIC);
INSERT INTO retdemo2 VALUES (random()), (random()), (random());
WITH source (average) AS ( SELECT AVG(x) FROM retdemo2) DELETE FROM retdemo2 USING source WHERE retdemo2.x < source.average;SELECT * FROM retdemo2;
CREATE TABLE
INSERT 0 3
DELETE 1
         x
-------------------
 0.776106251024559
 0.888078523784825
```

### [Recursive WITH to Delete Parts]

```sql
sample=# WITH RECURSIVE source (part_no) AS (SELECT 2        UNION ALL SELECT part.part_no FROM source JOIN part ON (source.part_no = part.parent_part_no))
DELETE FROM part USING source WHERE source.part_no = part.part_no;
DELETE 6
```

### [Using Both Features]

```sql
sample=# CREATE TEMPORARY TABLE retdemo3 (x NUMERIC);
INSERT INTO retdemo3 VALUES (random()), (random()), (random());WITH source (average) AS ( SELECT AVG(x) FROM retdemo3),     source2 AS ( DELETE FROM retdemo3 USING source  WHERE retdemo3.x < source.average  RETURNING x)SELECT * FROM source2;
CREATE TABLE
INSERT 0 3
         x
-------------------
 0.376604442280716
```

### [Chaining Modification Commands]

```sql
sample=# CREATE TEMPORARY TABLE orders (order_id SERIAL, name text);
CREATE TEMPORARY TABLE items (order_id INTEGER, part_id SERIAL, name text);
WITH source (order_id) AS (INSERT INTO orders VALUES (DEFAULT, 'my order') RETURNING order_id)INSERT INTO items (order_id, name) SELECT order_id, 'my part' FROM source;
WITH source (order_id) AS ( DELETE FROM orders WHERE name = 'my order' RETURNING order_id)DELETE FROM items USING source WHERE source.order_id = items.order_id;
CREATE TABLE
CREATE TABLE
INSERT 0 1
DELETE 1
```

### [Mixing Modification Commands]

```sql
sample=# CREATE TEMPORARY TABLE old_orders (order_id INTEGER, delete_user TEXT, delete_time TIMESTAMPTZ);
WITH source (order_id) AS (DELETE FROM orders WHERE name = 'my order' RETURNING order_id), source2 AS ( DELETE FROM items USING source WHERE source.order_id = items.order_id)INSERT INTO old_orders SELECT order_id, CURRENT_USER, CURRENT_TIMESTAMP FROM source;
CREATE TABLE
INSERT 0 0
```
