sample=# CREATE EXTENSION tablefunc;
CREATE EXTENSION
sample=#
sample=# --
sample=# -- normal_rand()
sample=# -- no easy way to do this for regression testing
sample=# --
sample=# SELECT avg(normal_rand)::int, count(*) FROM normal_rand(100, 250, 0.2);
 avg | count
-----+-------
 250 |   100
(1 行)


sample=# -- negative number of tuples
sample=# SELECT avg(normal_rand)::int, count(*) FROM normal_rand(-1, 250, 0.2);
ERROR:  number of rows cannot be negative

sample=# SELECT * FROM normal_rand(10, 10, 0);
 normal_rand
-------------
          10
          10
          10
          10
          10
          10
          10
          10
          10
          10
(10 行)

sample=# --
sample=# -- crosstab()
sample=# --
sample=# CREATE TABLE ct(id int, rowclass text, rowid text, attribute text, val text);
CREATE TABLE
sample=# \copy ct from 'C:\Users\user\OneDrive\デスクトップ\postgresql_expriments\tablefunc\ct.data'
COPY 18
sample=# SELECT * FROM crosstab2('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' and (attribute = ''att2'' or attribute = ''att3'') ORDER BY 1,2;');
 row_name | category_1 | category_2
----------+------------+------------
 test1    | val2       | val3
 test2    | val6       | val7
          | val10      | val11
(3 行)

sample=# SELECT * FROM crosstab3('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' and (attribute = ''att2'' or attribute = ''att3'') ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3
----------+------------+------------+------------
 test1    | val2       | val3       |
 test2    | val6       | val7       |
          | val10      | val11      |
(3 行)


sample=# SELECT * FROM crosstab4('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' and (attribute = ''att2'' or attribute = ''att3'') ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3 | category_4
----------+------------+------------+------------+------------
 test1    | val2       | val3       |            |
 test2    | val6       | val7       |            |
          | val10      | val11      |            |
(3 行)

sample=# SELECT * FROM crosstab2('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' ORDER BY 1,2;');
 row_name | category_1 | category_2
----------+------------+------------
 test1    | val1       | val2
 test2    | val5       | val6
          | val9       | val10
(3 行)


sample=# SELECT * FROM crosstab3('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3
----------+------------+------------+------------
 test1    | val1       | val2       | val3
 test2    | val5       | val6       | val7
          | val9       | val10      | val11
(3 行)


sample=# SELECT * FROM crosstab4('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3 | category_4
----------+------------+------------+------------+------------
 test1    | val1       | val2       | val3       | val4
 test2    | val5       | val6       | val7       | val8
          | val9       | val10      | val11      | val12
(3 行)

sample=# SELECT * FROM crosstab2('SELECT rowid, attribute, val FROM ct where rowclass = ''group2'' and (attribute = ''att1'' or attribute = ''att2'') ORDER BY 1,2;');
 row_name | category_1 | category_2
----------+------------+------------
 test3    | val1       | val2
 test4    | val4       | val5
(2 行)


sample=# SELECT * FROM crosstab3('SELECT rowid, attribute, val FROM ct where rowclass = ''group2'' and (attribute = ''att1'' or attribute = ''att2'') ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3
----------+------------+------------+------------
 test3    | val1       | val2       |
 test4    | val4       | val5       |
(2 行)


sample=# SELECT * FROM crosstab4('SELECT rowid, attribute, val FROM ct where rowclass = ''group2'' and (attribute = ''att1'' or attribute = ''att2'') ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3 | category_4
----------+------------+------------+------------+------------
 test3    | val1       | val2       |            |
 test4    | val4       | val5       |            |
(2 行)

sample=# SELECT * FROM crosstab2('SELECT rowid, attribute, val FROM ct where rowclass = ''group2'' ORDER BY 1,2;');
 row_name | category_1 | category_2
----------+------------+------------
 test3    | val1       | val2
 test4    | val4       | val5
(2 行)


sample=# SELECT * FROM crosstab3('SELECT rowid, attribute, val FROM ct where rowclass = ''group2'' ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3
----------+------------+------------+------------
 test3    | val1       | val2       | val3
 test4    | val4       | val5       | val6
(2 行)


sample=# SELECT * FROM crosstab4('SELECT rowid, attribute, val FROM ct where rowclass = ''group2'' ORDER BY 1,2;');
 row_name | category_1 | category_2 | category_3 | category_4
----------+------------+------------+------------+------------
 test3    | val1       | val2       | val3       |
 test4    | val4       | val5       | val6       |
(2 行)

sample=# SELECT * FROM crosstab('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' ORDER BY 1,2;') AS c(rowid text, att1 text, att2 text);
 rowid | att1 | att2
-------+------+-------
 test1 | val1 | val2
 test2 | val5 | val6
       | val9 | val10
(3 行)


sample=# SELECT * FROM crosstab('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' ORDER BY 1,2;') AS c(rowid text, att1 text, att2 text, att3 text);
 rowid | att1 | att2  | att3
-------+------+-------+-------
 test1 | val1 | val2  | val3
 test2 | val5 | val6  | val7
       | val9 | val10 | val11
(3 行)


sample=# SELECT * FROM crosstab('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' ORDER BY 1,2;') AS c(rowid text, att1 text, att2 text, att3 text, att4 text);
 rowid | att1 | att2  | att3  | att4
-------+------+-------+-------+-------
 test1 | val1 | val2  | val3  | val4
 test2 | val5 | val6  | val7  | val8
       | val9 | val10 | val11 | val12
(3 行)

sample=# -- check it works with OUT parameters, too
sample=#
sample=# CREATE FUNCTION crosstab_out(text,
sample(# OUT rowid text, OUT att1 text, OUT att2 text, OUT att3 text)
sample-# RETURNS setof record
sample-# AS '$libdir/tablefunc','crosstab'
sample-# LANGUAGE C STABLE STRICT;
CREATE FUNCTION
sample=#
sample=# SELECT * FROM crosstab_out('SELECT rowid, attribute, val FROM ct where rowclass = ''group1'' ORDER BY 1,2;');
 rowid | att1 | att2  | att3
-------+------+-------+-------
 test1 | val1 | val2  | val3
 test2 | val5 | val6  | val7
       | val9 | val10 | val11
(3 行)

sample=# --
sample=# -- connectby
sample=# --
sample=#
sample=# -- test connectby with text based hierarchy
sample=# CREATE TABLE connectby_text(keyid text, parent_keyid text, pos int);
CREATE TABLE
sample=# \copy connectby_text from 'C:\Users\user\OneDrive\デスクトップ\postgresql_expriments\tablefunc/connectby_text.data'
COPY 9
sample=# -- with branch, without orderby
sample=# SELECT * FROM connectby('connectby_text', 'keyid', 'parent_keyid', 'row2', 0, '~') AS t(keyid text, parent_keyid text, level int, branch text);
 keyid | parent_keyid | level |       branch
-------+--------------+-------+---------------------
 row2  |              |     0 | row2
 row4  | row2         |     1 | row2~row4
 row6  | row4         |     2 | row2~row4~row6
 row8  | row6         |     3 | row2~row4~row6~row8
 row5  | row2         |     1 | row2~row5
 row9  | row5         |     2 | row2~row5~row9
(6 行)


sample=#
sample=# -- without branch, without orderby
sample=# SELECT * FROM connectby('connectby_text', 'keyid', 'parent_keyid', 'row2', 0) AS t(keyid text, parent_keyid text, level int);
 keyid | parent_keyid | level
-------+--------------+-------
 row2  |              |     0
 row4  | row2         |     1
 row6  | row4         |     2
 row8  | row6         |     3
 row5  | row2         |     1
 row9  | row5         |     2
(6 行)


sample=#
sample=# -- with branch, with orderby
sample=# SELECT * FROM connectby('connectby_text', 'keyid', 'parent_keyid', 'pos', 'row2', 0, '~') AS t(keyid text, parent_keyid text, level int, branch text, pos int) ORDER BY t.pos;
 keyid | parent_keyid | level |       branch        | pos
-------+--------------+-------+---------------------+-----
 row2  |              |     0 | row2                |   1
 row5  | row2         |     1 | row2~row5           |   2
 row9  | row5         |     2 | row2~row5~row9      |   3
 row4  | row2         |     1 | row2~row4           |   4
 row6  | row4         |     2 | row2~row4~row6      |   5
 row8  | row6         |     3 | row2~row4~row6~row8 |   6
(6 行)


sample=#
sample=# -- without branch, with orderby
sample=# SELECT * FROM connectby('connectby_text', 'keyid', 'parent_keyid', 'pos', 'row2', 0) AS t(keyid text, parent_keyid text, level int, pos int) ORDER BY t.pos;
 keyid | parent_keyid | level | pos
-------+--------------+-------+-----
 row2  |              |     0 |   1
 row5  | row2         |     1 |   2
 row9  | row5         |     2 |   3
 row4  | row2         |     1 |   4
 row6  | row4         |     2 |   5
 row8  | row6         |     3 |   6
(6 行)

sample=# -- test connectby with int based hierarchy
sample=# CREATE TABLE connectby_int(keyid int, parent_keyid int);
CREATE TABLE
sample=# \copy connectby_int from 'C:\Users\user\OneDrive\デスクトップ\postgresql_expriments\tablefunc/connectby_int.data'
COPY 9
sample=# -- with branch
sample=# SELECT * FROM connectby('connectby_int', 'keyid', 'parent_keyid', '2', 0, '~') AS t(keyid int, parent_keyid int, level int, branch text);
 keyid | parent_keyid | level | branch
-------+--------------+-------+---------
     2 |              |     0 | 2
     4 |            2 |     1 | 2~4
     6 |            4 |     2 | 2~4~6
     8 |            6 |     3 | 2~4~6~8
     5 |            2 |     1 | 2~5
     9 |            5 |     2 | 2~5~9
(6 行)


sample=#
sample=# -- without branch
sample=# SELECT * FROM connectby('connectby_int', 'keyid', 'parent_keyid', '2', 0) AS t(keyid int, parent_keyid int, level int);
 keyid | parent_keyid | level
-------+--------------+-------
     2 |              |     0
     4 |            2 |     1
     6 |            4 |     2
     8 |            6 |     3
     5 |            2 |     1
     9 |            5 |     2
(6 行)

sample=# -- recursion detection
sample=# INSERT INTO connectby_int VALUES(10,9);
INSERT 0 1
sample=# INSERT INTO connectby_int VALUES(11,10);
INSERT 0 1
sample=# INSERT INTO connectby_int VALUES(9,11);
INSERT 0 1
sample=#
sample=# -- should fail due to infinite recursion
sample=# SELECT * FROM connectby('connectby_int', 'keyid', 'parent_keyid', '2', 0, '~') AS t(keyid int, parent_keyid int, level int, branch text);
ERROR:  infinite recursion detected

sample=# -- infinite recursion failure avoided by depth limit
sample=# SELECT * FROM connectby('connectby_int', 'keyid', 'parent_keyid', '2', 4, '~') AS t(keyid int, parent_keyid int, level int, branch text);
 keyid | parent_keyid | level |   branch
-------+--------------+-------+-------------
     2 |              |     0 | 2
     4 |            2 |     1 | 2~4
     6 |            4 |     2 | 2~4~6
     8 |            6 |     3 | 2~4~6~8
     5 |            2 |     1 | 2~5
     9 |            5 |     2 | 2~5~9
    10 |            9 |     3 | 2~5~9~10
    11 |           10 |     4 | 2~5~9~10~11
(8 行)

sample=# -- should fail as key field datatype should match return datatype
sample=# SELECT * FROM connectby('connectby_int', 'keyid', 'parent_keyid', '2', 0, '~') AS t(keyid float8, parent_keyid float8, level int, branch text);
ERROR:  invalid return type
DETAIL:  SQL key field type double precision does not match return key field type integer.