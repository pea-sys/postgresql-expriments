
DO $$
DECLARE
 r record;
 t timestamp;
BEGIN
	FOR i IN 1..5 LOOP
		t := clock_timestamp();
    	FOR r IN SELECT * FROM pgbench_accounts
    	LOOP
    	END LOOP;
		--raise info '%' , clock_timestamp() - t;
	END LOOP;
END$$;