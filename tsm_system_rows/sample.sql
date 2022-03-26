
sample=# CREATE EXTENSION tsm_system_rows;
CREATE EXTENSION
sample=#
sample=# CREATE TABLE test_tablesample (id int, name text);
CREATE TABLE
sample=# INSERT INTO test_tablesample SELECT i, repeat(i::text, 1000)
sample-#   FROM generate_series(0, 30) s(i);
INSERT 0 31
sample=# ANALYZE test_tablesample;
ANALYZE
sample=#
sample=# SELECT count(*) FROM test_tablesample TABLESAMPLE system_rows (0);
 count
-------
     0
(1 行)


sample=# SELECT count(*) FROM test_tablesample TABLESAMPLE system_rows (1);
 count
-------
     1
(1 行)


sample=# SELECT count(*) FROM test_tablesample TABLESAMPLE system_rows (10);
 count
-------
    10
(1 行)


sample=# SELECT count(*) FROM test_tablesample TABLESAMPLE system_rows (100);
 count
-------
    31
(1 行)


sample=# -- bad parameters should get through planning, but not execution:
sample=# EXPLAIN (COSTS OFF)
sample-# SELECT id FROM test_tablesample TABLESAMPLE system_rows (-1);
               QUERY PLAN
----------------------------------------
 Sample Scan on test_tablesample
   Sampling: system_rows ('-1'::bigint)
(2 行)


sample=#
sample=# SELECT id FROM test_tablesample TABLESAMPLE system_rows (-1);
ERROR:  sample size must not be negative
sample=#
sample=# -- fail, this method is not repeatable:
sample=# SELECT * FROM test_tablesample TABLESAMPLE system_rows (10) REPEATABLE (0);
ERROR:  テーブルサンプルメソッドsystem_rowsはREPEATABLEをサポートしていません
行 1: SELECT * FROM test_tablesample TABLESAMPLE system_rows (10) ...
                                                 ^
sample=# -- but a join should be allowed:
sample=# EXPLAIN (COSTS OFF)
sample-# SELECT * FROM
sample-#   (VALUES (0),(10),(100)) v(nrows),
sample-#   LATERAL (SELECT count(*) FROM test_tablesample
sample(#            TABLESAMPLE system_rows (nrows)) ss;
                        QUERY PLAN
----------------------------------------------------------
 Nested Loop
   ->  Values Scan on "*VALUES*"
   ->  Aggregate
         ->  Sample Scan on test_tablesample
               Sampling: system_rows ("*VALUES*".column1)
(5 行)


sample=#
sample=# SELECT * FROM
sample-#   (VALUES (0),(10),(100)) v(nrows),
sample-#   LATERAL (SELECT count(*) FROM test_tablesample
sample(#            TABLESAMPLE system_rows (nrows)) ss;
 nrows | count
-------+-------
     0 |     0
    10 |    10
   100 |    31
(3 行)


sample=#
sample=# CREATE VIEW vv AS
sample-#   SELECT count(*) FROM test_tablesample TABLESAMPLE system_rows (20);
CREATE VIEW
sample=#
sample=# SELECT * FROM vv;
 count
-------
    20
(1 行)


sample=# DROP EXTENSION tsm_system_rows;  -- fail, view depends on extension
ERROR:  他のオブジェクトが依存しているため機能拡張tsm_system_rowsを削除できません
DETAIL:  ビューvvは関数system_rows(internal)に依存しています
HINT:  依存しているオブジェクトも削除するにはDROP ... CASCADEを使用してください
sample=# DROP EXTENSION tsm_system_rows cascade;
NOTICE:  削除はビューvvへ伝播します
DROP EXTENSION