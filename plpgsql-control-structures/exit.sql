DO $$	
DECLARE myvar int := 10;	
BEGIN	
<<ablock>>	
LOOP	
	myvar := myvar - 1;
    IF myvar > 8 THEN	
	
	ELSIF myvar = 7 THEN
	    raise info '%', myvar;
	
	END IF;
END LOOP;	
LOOP	
	myvar := myvar - 1;
	IF myvar < 5 THEN
	
        EXIT;	
    END IF;	
END LOOP;	
END$$;	
