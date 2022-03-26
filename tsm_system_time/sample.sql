sample=# CREATE EXTENSION tsm_system_time;
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
sample=# -- It's a bit tricky to test SYSTEM_TIME in a platform-independent way.
sample=# -- We can test the zero-time corner case ...
sample=# SELECT count(*) FROM test_tablesample TABLESAMPLE system_time (0);
 count
-------
     0
(1 行)


sample=# -- ... and we assume that this will finish before running out of time:
sample=# SELECT count(*) FROM test_tablesample TABLESAMPLE system_time (100000);
 count
-------
    31
(1 行)


sample=#
sample=# -- bad parameters should get through planning, but not execution:
sample=# EXPLAIN (COSTS OFF)
sample-# SELECT id FROM test_tablesample TABLESAMPLE system_time (-1);
                    QUERY PLAN
--------------------------------------------------
 Sample Scan on test_tablesample
   Sampling: system_time ('-1'::double precision)
(2 行)


sample=#
sample=# SELECT id FROM test_tablesample TABLESAMPLE system_time (-1);
ERROR:  sample collection time must not be negative
sample=#
sample=# -- fail, this method is not repeatable:
sample=# SELECT * FROM test_tablesample TABLESAMPLE system_time (10) REPEATABLE (0);
ERROR:  テーブルサンプルメソッドsystem_timeはREPEATABLEをサポートしていません
行 1: SELECT * FROM test_tablesample TABLESAMPLE system_time (10) ...
                                                 ^
sample=#
sample=# -- since it's not repeatable, we expect a Materialize node in these plans:
sample=# EXPLAIN (COSTS OFF)
sample-# SELECT * FROM
sample-#   (VALUES (0),(100000)) v(time),
sample-#   LATERAL (SELECT COUNT(*) FROM test_tablesample
sample(#            TABLESAMPLE system_time (100000)) ss;
                               QUERY PLAN
------------------------------------------------------------------------
 Nested Loop
   ->  Aggregate
         ->  Materialize
               ->  Sample Scan on test_tablesample
                     Sampling: system_time ('100000'::double precision)
   ->  Values Scan on "*VALUES*"
(6 行)


sample=#
sample=# SELECT * FROM
sample-#   (VALUES (0),(100000)) v(time),
sample-#   LATERAL (SELECT COUNT(*) FROM test_tablesample
sample(#            TABLESAMPLE system_time (100000)) ss;
  time  | count
--------+-------
      0 |    31
 100000 |    31
(2 行)


sample=#
sample=# EXPLAIN (COSTS OFF)
sample-# SELECT * FROM
sample-#   (VALUES (0),(100000)) v(time),
sample-#   LATERAL (SELECT COUNT(*) FROM test_tablesample
sample(#            TABLESAMPLE system_time (time)) ss;
                           QUERY PLAN
----------------------------------------------------------------
 Nested Loop
   ->  Values Scan on "*VALUES*"
   ->  Aggregate
         ->  Materialize
               ->  Sample Scan on test_tablesample
                     Sampling: system_time ("*VALUES*".column1)
(6 行)


sample=#
sample=# SELECT * FROM
sample-#   (VALUES (0),(100000)) v(time),
sample-#   LATERAL (SELECT COUNT(*) FROM test_tablesample
sample(#            TABLESAMPLE system_time (time)) ss;
  time  | count
--------+-------
      0 |     0
 100000 |    31
(2 行)


sample=#
sample=# CREATE VIEW vv AS
sample-#   SELECT * FROM test_tablesample TABLESAMPLE system_time (20);
CREATE VIEW
sample=#
sample=# EXPLAIN (COSTS OFF) SELECT * FROM vv;
                    QUERY PLAN
--------------------------------------------------
 Sample Scan on test_tablesample
   Sampling: system_time ('20'::double precision)
(2 行)


sample=#
sample=# DROP EXTENSION tsm_system_time;  -- fail, view depends on extension
ERROR:  他のオブジェクトが依存しているため機能拡張tsm_system_timeを削除できません
DETAIL:  ビューvvは関数system_time(internal)に依存しています
HINT:  依存しているオブジェクトも削除するにはDROP ... CASCADEを使用してください
sample=# DROP EXTENSION tsm_system_time cascade ;
NOTICE:  削除はビューvvへ伝播します
DROP EXTENSION