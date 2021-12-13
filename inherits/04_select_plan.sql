EXPLAIN ANALYZE SELECT name, size
  FROM public.drink_tbl;

-- "Append  (cost=0.00..25.07 rows=938 width=64) (actual time=0.039..0.071 rows=6 loops=1)"
-- "  ->  Seq Scan on drink_tbl drink_tbl_1  (cost=0.00..1.88 rows=88 width=64) (actual time=0.036..0.038 rows=3 loops=1)"
-- "  ->  Seq Scan on alcohol_tbl drink_tbl_2  (cost=0.00..18.50 rows=850 width=64) (actual time=0.024..0.026 rows=3 loops=1)"
-- "Planning Time: 0.288 ms"
-- "Execution Time: 0.106 ms"

EXPLAIN ANALYZE SELECT name, size
  FROM only public.drink_tbl;

-- "Seq Scan on drink_tbl  (cost=0.00..1.88 rows=88 width=64) (actual time=0.019..0.021 rows=3 loops=1)"
-- "Planning Time: 0.087 ms"
-- "Execution Time: 0.035 ms"

