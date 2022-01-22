DO $$DECLARE r record;
DECLARE
    x int;
BEGIN
    create temp sequence temp_seq;
    select into x nextval('sample_seq');
    select into x nextval('temp_seq');
    raise notice 'next_val=%',x;
    select into x lastval();
    raise notice 'last_val=%',x;
    select into x nextval('sample_seq');
    raise notice 'next_val=%',x;
    select into x lastval();
    raise notice 'last_val=%',x;
END$$;