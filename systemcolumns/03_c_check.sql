update t1 set value = 999 where value >= 500;
select tableoid, xmin, cmin, xmax, cmax, name, value ctid from t1;

--23254;12062;7;0;7;"tea";100
--23254;12062;9;0;9;"X";50
--23254;12062;10;0;10;"Y";100
--23254;12063;0;0;0;"water";999

