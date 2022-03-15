DO $$
DECLARE
 r record;
 search_id constant int := -9999;
BEGIN
	SELECT * INTO r FROM pgbench_accounts WHERE aid = search_id ;
	IF NOT FOUND THEN
    	RAISE EXCEPTION 'actor % not found', search_id;
END IF;
END$$;