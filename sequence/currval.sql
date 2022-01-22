DO $$DECLARE r record;
DECLARE
    x int;
BEGIN
    select into x nextval('sample_seq');
    raise notice 'next_val=%',x;
    select into x currval('sample_seq');
    raise notice 'curr_val=%',x;
    select into x nextval('sample_seq');
    raise notice 'next_val=%',x;
END$$;