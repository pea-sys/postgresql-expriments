DO $$
  DECLARE
    rec record;
    nbrow bigint;
  BEGIN
    FOR rec IN 
	select viewname from pg_views where viewname  ilike 'pg#_stat#_%' escape '#'
    LOOP 
	EXECUTE 'SELECT count(*) FROM '
        || quote_ident(rec.viewname)
      INTO nbrow;
      RAISE NOTICE '%', rec.viewname || ' = ' || nbrow;
    END LOOP;
  END;
$$ LANGUAGE plpgsql;