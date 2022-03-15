DO $$
DECLARE
 r record;
 search_id constant int := 3;
BEGIN
	SELECT * INTO STRICT r FROM pgbench_accounts WHERE aid < search_id ;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN
    		RAISE EXCEPTION 'actor % not found', search_id;
		WHEN TOO_MANY_ROWS THEN
        	RAISE EXCEPTION 'actor % not unique', search_id;
END$$;