CREATE OR REPLACE FUNCTION print()
RETURNS void AS $$
BEGIN
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
	c record;

BEGIN
--SELECT INTO文は、行が代入された場合は真、返されなかった場合は偽をFOUNDに設定します。
SELECT * FROM pgbench_accounts into c WHERE aid < 5 AND bid = 1;
raise info '%',found;
SELECT * FROM pgbench_accounts into c WHERE aid < -1 AND bid = 1;
raise info '%',found;
--PERFORM文は、1つ以上の行が生成（破棄）された場合は真、まったく生成されなかった場合は偽をFOUNDに設定します。
perform 1;
raise info '%',found;
perform print();
raise info '%',found;
--UPDATE、INSERT、およびDELETE文は、少なくとも1行が影響を受けた場合は真、まったく影響を受けなかった場合は偽をFOUNDに設定します。
delete from pgbench_accounts where aid = 2;
raise info '%',found;
delete from pgbench_accounts where aid = 2;
raise info '%',found;
END$$;