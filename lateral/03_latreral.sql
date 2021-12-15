-- SELECT t1.id, t1.name, ss.value FROM t1 ,
--   (SELECT value FROM t2 WHERE t2.name = t1.name)ss;

-- EXPLAIN ANALYZE SELECT t1.name, ss.value FROM t1,
--    (SELECT name , value FROM t2)ss WHERE ss.name = t1.name;

 EXPLAIN ANALYZE  WITH s AS (SELECT name, value FROM t1)
    SELECT s.name, s.value, t2.value FROM s, t2 WHERE s.name = t2.name;

/*
"Hash Join  (cost=35.42..59.70 rows=1130 width=56) (actual time=0.105..0.113 rows=2 loops=1)"
"  Hash Cond: (t1.name = t2.name)"
"  ->  Seq Scan on t1  (cost=0.00..21.30 rows=1130 width=44) (actual time=0.032..0.035 rows=4 loops=1)"
"  ->  Hash  (cost=21.30..21.30 rows=1130 width=44) (actual time=0.039..0.040 rows=2 loops=1)"
"        Buckets: 2048  Batches: 1  Memory Usage: 17kB"
"        ->  Seq Scan on t2  (cost=0.00..21.30 rows=1130 width=44) (actual time=0.022..0.024 rows=2 loops=1)"
"Planning Time: 0.340 ms"
"Execution Time: 0.157 ms"

*/
--EXPLAIN ANALYZE SELECT t1.name, ss.value FROM t1 ,
--    LATERAL (SELECT value FROM t2 WHERE t2.name = t1.name)ss;

/*
"Hash Join  (cost=35.42..59.70 rows=1130 width=44) (actual time=0.517..0.526 rows=2 loops=1)"
"  Hash Cond: (t1.name = t2.name)"
"  ->  Seq Scan on t1  (cost=0.00..21.30 rows=1130 width=32) (actual time=0.454..0.456 rows=4 loops=1)"
"  ->  Hash  (cost=21.30..21.30 rows=1130 width=44) (actual time=0.038..0.039 rows=2 loops=1)"
"        Buckets: 2048  Batches: 1  Memory Usage: 17kB"
"        ->  Seq Scan on t2  (cost=0.00..21.30 rows=1130 width=44) (actual time=0.026..0.029 rows=2 loops=1)"
"Planning Time: 0.374 ms"
"Execution Time: 0.618 ms"
*/
