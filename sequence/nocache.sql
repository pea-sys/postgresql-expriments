DO $$
DECLARE
  x int;
BEGIN
  FOR i IN 1..2000000 LOOP
    select into x nextval('temp_seq_nocache'); 
  END LOOP:
  END LOOP;
END
$$