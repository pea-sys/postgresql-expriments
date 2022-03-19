--ERROR:  query returned more than one row
--HINT:  Make sure the query returns a single row, or use LIMIT 1.
--CONTEXT:  PL/pgSQL function inline_code_block line 4 at SQL statement
--SQL 状態: P0003
SET plpgsql.extra_errors TO 'too_many_rows' ;

DO $$
DECLARE x INTEGER ;
BEGIN
 SELECT generate_series(1,2) INTO x ;
 RAISE NOTICE 'test output' ;
END ;
$$ ;