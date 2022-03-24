sample=# create extension pg_visibility;
CREATE EXTENSION

sample=# delete from pgbench_accounts where aid = 1;
DELETE 1

sample=# select pg_visibility_map('pgbench_accounts',0);
 pg_visibility_map
-------------------
 (f,f)
sample=# select pg_visibility('pgbench_accounts',0);
 pg_visibility
---------------
 (f,f,f)
(1 行)
sample=# select pg_visibility_map('pgbench_accounts');
 pg_visibility_map
-------------------
 (0,f,f)
 (1,t,f)
 (2,t,f)
 (3,t,f)
 (4,t,f)
 (5,t,f)
 (6,t,f)
 (7,t,f)
 (8,t,f)
 (9,t,f)
 (10,t,f)
 (11,t,f)
 (12,t,f)
 (13,t,f)
 (14,t,f)
 (15,t,f)
 (16,t,f)
 (17,t,f)
 (18,t,f)
 (19,t,f)
 (20,t,f)
 (21,t,f)
 (22,t,f)
 (23,t,f)
 (24,t,f)
 (25,t,f)
 (26,t,f)
-- More  --

sample=# select pg_visibility('pgbench_accounts');
 pg_visibility
---------------
 (0,f,f,f)
 (1,t,f,t)
 (2,t,f,t)
 (3,t,f,t)
 (4,t,f,t)
 (5,t,f,t)
 (6,t,f,t)
 (7,t,f,t)
 (8,t,f,t)
 (9,t,f,t)

sample=# select pg_visibility_map_summary('pgbench_accounts');
 pg_visibility_map_summary
---------------------------
 (4918,0)
(1 行)

sample=# select pg_check_frozen('pgbench_accounts');
 pg_check_frozen
-----------------
(0 行)

sample=# select pg_check_visible('pgbench_accounts');
 pg_check_visible
------------------
(0 行)

sample=# select pg_truncate_visibility_map('pgbench_accounts');
 pg_truncate_visibility_map
----------------------------

(1 行)