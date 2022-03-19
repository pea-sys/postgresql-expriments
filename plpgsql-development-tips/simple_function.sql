CREATE OR REPLACE FUNCTION testfunc(int) RETURNS integer AS $$
BEGIN
	return $1;
END;
$$ LANGUAGE plpgsql;
