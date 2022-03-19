create table foo (foo text);

DO $$
<<deco>>
DECLARE
 foo text;
BEGIN
  INSERT INTO foo (foo) VALUES (deco.foo);
END$$;