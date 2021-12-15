CREATE OR REPLACE FUNCTION delete_item(delete_name text)
RETURNS void AS $$
    BEGIN
        DELETE FROM t1 WHERE "name" = delete_name;
        DELETE FROM t2 WHERE "name" = delete_name;
    END; 
$$ LANGUAGE plpgsql;

SELECT * FROM (
    SELECT t1.name FROM t1 WHERE value = 100
) c, LATERAL delete_item(c.name);