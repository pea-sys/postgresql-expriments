CREATE OR REPLACE FUNCTION testfunc() RETURNS text AS '
DECLARE
    a text;
BEGIN
    a := ''AND name LIKE ''''foobar'''' AND xyz'';
	return a;
END;
'LANGUAGE plpgsql;