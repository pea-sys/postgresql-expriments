CREATE TABLE foo (fooid INT, foosubid INT, fooname TEXT);
INSERT INTO foo VALUES (1, 2, 'three');
INSERT INTO foo VALUES (4, 5, 'six');

CREATE OR REPLACE FUNCTION get_all_foo() RETURNS SETOF foo AS
$BODY$
DECLARE
    r foo%rowtype;
BEGIN
    FOR r IN
        SELECT * FROM foo WHERE fooid > 0
    LOOP

        -- ここで処理を実行できます
        RETURN NEXT r; -- SELECTの現在の行を返します
    END LOOP;
    RETURN;
END;
$BODY$
LANGUAGE plpgsql;