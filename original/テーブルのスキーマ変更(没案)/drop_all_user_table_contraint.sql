DO $body$
DECLARE r record;
BEGIN
    FOR r IN SELECT table_name,constraint_name
             FROM information_schema.constraint_table_usage where constraint_schema not like 'pg_%' and constraint_schema != 'information_schema'
    LOOP
	BEGIN
       EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name)|| ' DROP CONSTRAINT '|| quote_ident(r.constraint_name) || ' CASCADE;';
    EXCEPTION WHEN OTHERS THEN
		-- keep looping
	END;
	END LOOP;
END
$body$;