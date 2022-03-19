create table foo (foo text);

DO $$
DECLARE
 foo text;
BEGIN
  INSERT INTO foo (foo) VALUES (foo);
END$$;