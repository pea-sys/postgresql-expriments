DO $$
DECLARE
  x int;
  dummy_id integer;
BEGIN
  x:= 5;
  dummy_id = (random()* 10000)::int % 100; 
  FOR a IN 1..x LOOP
    execute 'select pg_advisory_xact_lock_shared(123);';
    RAISE INFO '% Lock %',dummy_id, clock_timestamp();
    execute 'select pg_sleep(2);';
    execute 'select pg_advisory_unlock_all();';
    RAISE INFO '% UnLock %',dummy_id, clock_timestamp();
    execute 'select pg_sleep(2);';
    x := x + 1;
  END LOOP;
END;
$$
LANGUAGE plpgsql;