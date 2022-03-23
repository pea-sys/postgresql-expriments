>pgbench -i -U postgres -s 3 -d sample
dropping old tables...
creating tables...
generating data (client-side)...
300000 of 300000 tuples (100%) done (elapsed 0.17 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 1.59 s (drop tables 0.03 s, create tables 0.02 s, client-side generate 1.02 s, vacuum 0.23 s, primary keys 0.30 s).

psql -U postgres -d sample
psql (14.2)
"help"でヘルプを表示します。

sample=# create extension pgstattuple;
CREATE EXTENSION

sample=# select pgstattuple('pgbench_accounts');
                    pgstattuple
----------------------------------------------------
 (40296448,300000,36300000,90.08,0,0,0,558716,1.39)
(1 行)

sample=# CREATE INDEX ON pgbench_accounts (aid);
CREATE INDEX

sample=# select pgstatindex('pgbench_accounts_aid_idx');
             pgstatindex
-------------------------------------
 (4,2,6758400,290,4,820,0,0,90.05,0)
(1 行)