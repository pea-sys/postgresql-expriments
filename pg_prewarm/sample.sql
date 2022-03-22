C:\Windows\system32>psql -U postgres -d sample
psql (14.2)
"help"でヘルプを表示します。

sample=#   explain analyze table pgbench_accounts;
                                                         QUERY PLAN                                                     
-----------------------------------------------------------------------------------------------------------------------------
 Seq Scan on pgbench_accounts  (cost=0.00..26394.00 rows=1000000 width=97) (actual time=0.051..176.147 rows=1000000 loops=1)
 Planning Time: 2.735 ms
 Execution Time: 205.681 ms
(3 行)


sample=# select pg_prewarm('pgbench_accounts', 'buffer','main');
 pg_prewarm
------------
      16394
(1 行)


sample=#   explain analyze table pgbench_accounts;
                                                         QUERY PLAN                                                     
----------------------------------------------------------------------------------------------------------------------------
 Seq Scan on pgbench_accounts  (cost=0.00..26394.00 rows=1000000 width=97) (actual time=0.051..76.225 rows=1000000 loops=1)
 Planning Time: 0.075 ms
 Execution Time: 106.890 ms
(3 行)