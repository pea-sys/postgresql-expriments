DO $$	
DECLARE r record;	
BEGIN
	FOR r IN SELECT GENERATE_SERIES(1, 10) LOOP
		raise info '%',r;
	END LOOP;
END$$;