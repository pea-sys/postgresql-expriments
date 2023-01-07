# テーブルアライメント

テーブルのサイズはカラムの並び順によって変わる場合があります。
これはカラムの型によっては、データの整列格納の目的でパティングが入る場合があるためです。  
基本的には 8 バイト列>4 バイト列>2 バイト列>可変列の順で配置すれば、綺麗に配置されます。boolean や uuid はパティングを必要としないらしいので、どこに配置しても OK。

実際にテーブルアライメントを試してみます。  
対象データベースは以下から入手します。

https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/

- 1.psql から DB にアクセスします

- 2.DB 作成

```postgresql
CREATE DATABASE dvdrental;
```

- 3.DB をリストア

```
pg_restore -U postgres -d dvdrental C:\Users\user\Downloads\dvdrental.tar
```

- 4.データベースサイズを測定

```postgresql
postgres=# SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database where datname='dvdrental';
  datname  | pg_size_pretty
-----------+----------------
 dvdrental | 15 MB
(1 行)
```

- 5.テーブルサイズを取得

```postgresql
dvdrental=# SELECT relname as table_name,
dvdrental-# reltuples as row_num,
dvdrental-# (relpages * 8192) as byte_size FROM pg_catalog.pg_class where  relreplident = 'd' and relnamespace = (select oid from pg_namespace where nspname = 'public');
  table_name   | row_num | byte_size
---------------+---------+-----------
 actor         |     200 |     16384
 store         |       2 |      8192
 address       |     603 |     65536
 category      |      16 |      8192
 city          |     600 |     40960
 country       |     109 |      8192
 customer      |     599 |     73728
 film_actor    |    5462 |    245760
 film_category |    1000 |     49152
 inventory     |    4581 |    204800
 language      |       6 |      8192
 rental        |   16044 |   1228800
 staff         |       2 |      8192
 payment       |   14596 |    884736
 film          |    1000 |    442368
```

- 6.一番サイズの大きい rental テーブルのカラム順を確認

```postgresql
dvdrental=# SELECT * FROM public.rental limit 0;
 rental_id | rental_date | inventory_id | customer_id | return_date | staff_id | last_update
```

- 7.最後尾に貼ったリンクにアライメントを進めるのに便利な SQL があるので実行してみます

```postgresql
dvdrental=# SELECT a.attname, t.typname, t.typalign, t.typlen
dvdrental-# FROM pg_class c
dvdrental-# JOIN pg_attribute a ON (a.attrelid = c.oid)
dvdrental-# JOIN pg_type t ON (t.oid = a.atttypid)
dvdrental-# WHERE c.relname = 'rental'
dvdrental-#  AND a.attnum >= 0
dvdrental-# ORDER BY t.typlen DESC;
   attname    |  typname  | typalign | typlen
--------------+-----------+----------+--------
 rental_date  | timestamp | d        |      8
 last_update  | timestamp | d        |      8
 return_date  | timestamp | d        |      8
 inventory_id | int4      | i        |      4
 rental_id    | int4      | i        |      4
 customer_id  | int2      | s        |      2
 staff_id     | int2      | s        |      2
(7 行)
```

- 8.新しくアライメントしたテーブルを作成します。  
  依存関係はここでは無視します。

```postgresql
create table rental_new (
	rental_date timestamp,
	last_update timestamp,
	return_date timestamp,
	inventory_id int4,
	rental_id int4,
	customer_id int2,
	staff_id int2
)
```

- 9.rental テーブルの内容を rental_new にコピーします。

```postgresql
insert into rental_new (rental_date, last_update, return_date,inventory_id,rental_id,staff_id)
select rental_date, last_update, return_date,inventory_id,rental_id,staff_id from rental;
INSERT 0 16044
```

- 10.アライメントしたテーブルサイズを確認します。

```postgresql
dvdrental=# SELECT relname as table_name,
dvdrental-# reltuples as row_num,
dvdrental-# (relpages * 8192) as byte_size FROM pg_catalog.pg_class where  relreplident = 'd' and relnamespace = (select oid from pg_namespace where nspname = 'public');
  table_name   | row_num | byte_size
---------------+---------+-----------
・・・
 rental        |   16044 |   1228800
・・・
 rental_new    |   16044 |   1097728
(16 行)
```

凡そ、1 割のデータを削減できました。
これはかなり大きい効果ですね。

- 11.快感なので payment テーブルもついでにやっていきます。

```postgresql
dvdrental=# SELECT * FROM public.payment limit 0;
 payment_id | customer_id | staff_id | rental_id | amount | payment_date
------------+-------------+----------+-----------+--------+--------------
(0 行)
```

```postgresql
dvdrental=# SELECT a.attname, t.typname, t.typalign, t.typlen
dvdrental-# FROM pg_class c
dvdrental-# JOIN pg_attribute a ON (a.attrelid = c.oid)
dvdrental-# JOIN pg_type t ON (t.oid = a.atttypid)
dvdrental-# WHERE c.relname = 'payment'
dvdrental-#  AND a.attnum >= 0
dvdrental-# ORDER BY t.typlen DESC;
   attname    |  typname  | typalign | typlen
--------------+-----------+----------+--------
 payment_date | timestamp | d        |      8
 payment_id   | int4      | i        |      4
 rental_id    | int4      | i        |      4
 customer_id  | int2      | s        |      2
 staff_id     | int2      | s        |      2
 amount       | numeric   | i        |     -1
(6 行)
```

- 12.新しくアライメントしたテーブルを作成します。  
  依存関係はここでは無視します。numeric があるので良い例ですね。

```postgresql
create table payment_new (
 payment_date timestamp,
 payment_id  int4,
 rental_id  int4,
 customer_id int2,
 staff_id int2,
 amount numeric
)
```

- 13.payment テーブルの内容を payment_new にコピーします。

```postgresql
insert into payment_new (payment_date , payment_id, rental_id , customer_id, staff_id, amount)
select payment_date , payment_id, rental_id , customer_id, staff_id, amount from payment;
```

- 14.アライメントしたテーブルサイズを確認します。

```postgresql
dvdrental=# SELECT relname as table_name,
dvdrental-# reltuples as row_num,
dvdrental-# (relpages * 8192) as byte_size FROM pg_catalog.
dvdrental-# pg_class where  relreplident = 'd' and relnamespace = (select oid from pg_namespace where nspname = 'public');
  table_name   | row_num | byte_size
---------------+---------+-----------
・・・
 payment       |   14596 |    884736
 ・・・
 payment_new   |   14596 |    884736
(17 行)
```

変わりませんでした。可変長の numeric が丁度良いサイズになっていたようです。

---

StackOverFlow の次のページは大変参考になります。  
https://stackoverflow.com/questions/2966524/calculating-and-saving-space-in-postgresql/7431468#7431468
