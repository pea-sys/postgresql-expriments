DO $$
DECLARE
	c int;
	x text;
	t constant text := 'pgbench_accounts';
BEGIN
EXECUTE 'SELECT * FROM '
    || quote_ident(t)
    || ' WHERE aid < $1 AND bid = $2'
   USING 10, 1;
   GET DIAGNOSTICS c = ROW_COUNT;
   GET DIAGNOSTICS x = PG_CONTEXT;
   raise info 'row_count=% context=%',c,x;
END$$;