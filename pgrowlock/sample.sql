C:\Users\user>psql -U postgres -d sample
psql (14.2)
"help"でヘルプを表示します。

sample=# begin;
BEGIN
sample=*# update actor set first_name='a' where actor_id =1;
UPDATE 1
sample=*# SELECT * FROM actor AS a, pgrowlocks('actor') AS p
sample-*#   WHERE p.locked_row = a.ctid;
 actor_id | first_name | last_name |        last_update         | locked_row | locker | multi |  xids  |       modes       |  pids
----------+------------+-----------+----------------------------+------------+--------+-------+--------+-------------------+---------
        1 | a          | Guiness   | 2022-03-22 19:17:56.105972 | (1,59)     |   1031 | f     | {1031} | {"For Key Share"} | {10900}
(1 行)