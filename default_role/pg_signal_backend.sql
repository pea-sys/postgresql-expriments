DO $$
  DECLARE
    rec record;
    nbrow bigint;
  BEGIN
    FOR rec IN 
	select pid from pg_stat_activity
    LOOP 
	EXECUTE 'select pg_terminate_backend(' || rec.pid || ')';
      RAISE NOTICE 'kill session%', rec.pid;
    END LOOP;
  END;
$$ LANGUAGE plpgsql;