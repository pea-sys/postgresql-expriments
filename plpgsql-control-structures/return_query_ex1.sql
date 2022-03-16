CREATE TABLE flight (flightid INT, flightdate timestamp);
INSERT INTO flight VALUES (1, now());
INSERT INTO flight VALUES (4, now() + '1 month');

CREATE OR REPLACE FUNCTION get_available_flightid(date) RETURNS SETOF integer AS
$BODY$
BEGIN
    RETURN QUERY SELECT flightid
                   FROM flight
                  WHERE flightdate >= $1
                    AND flightdate < ($1 + 1);


-- 実行が終わっていないので、行が返されたか検査して、行がなければ例外を発生させます。
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No flight at %.', $1;
    END IF;

    RETURN;
 END;
$BODY$
LANGUAGE plpgsql;