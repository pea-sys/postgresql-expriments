BEGIN;
SAVEPOINT foo;

DELETE FROM public.t1 WHERE value = 999;

ROLLBACK TO foo;
select tableoid, xmin, cmin, xmax, cmax, name, value ctid from t1;

--23254;12062;7;0;7;"tea";100
--23254;12062;9;0;9;"X";50
--23254;12062;10;0;10;"Y";100
--23254;12063;0;12065;0;"water";999

