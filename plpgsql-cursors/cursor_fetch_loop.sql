DO $$	
DECLARE
    var_rec RECORD;
    var_cursor CURSOR FOR SELECT * FROM pgbench_branches;
BEGIN
    OPEN var_cursor;
    LOOP
	FETCH var_cursor INTO var_rec;
	IF NOT FOUND THEN
	  EXIT;
	END IF;
	RAISE NOTICE 'row1=%', var_rec.bid;
    END LOOP;
    CLOSE var_cursor;
END$$;
