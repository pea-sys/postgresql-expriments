DO $$	
DECLARE
    var_cursor CURSOR FOR SELECT * FROM pgbench_branches;
BEGIN
    FOR var_rec IN var_cursor LOOP 
	RAISE NOTICE 'row1=%',var_rec.bid;
    END LOOP;
END$$;