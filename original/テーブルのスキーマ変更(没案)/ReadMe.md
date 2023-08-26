# テーブルのスキーマ変更

データ分析用に複数のデータベースダンプをリストアして集計したい。  
集計対象の DB があるシステムはスタンドアローンのため、ユーザーの数だけ DB が存在する。  
その為に以下のような方法を考える。

---

- 1. データベースをリストアする
- 2. 集計に使用しないテーブルやビュー型などを削除する
- 3. スキーマを変更する(スキーマ名は店舗毎に重複しないようにする)

---

データ集計用の DB 作成

```psql
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE hub TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
```

DB を restore

```psql
pg_restore -U postgres -d hub ./dvdrental.tar
```

今回はユーザー毎にスタンドアロンで動作している DB を集約する体にしたいので store_id=2 のデータはドロップします

```
hub=# select * from store;
 store_id | manager_staff_id | address_id |     last_update
----------+------------------+------------+---------------------
        1 |                1 |          1 | 2006-02-15 09:57:12
        2 |                2 |          2 | 2006-02-15 09:57:12
(2 行)
```

ドロップにあたり、制約が鬱陶しいのでドロップします。  
現実ではちゃんと制約は残して、検索性能の低下が起きないようにするべきです。

```sql
DO $body$
DECLARE r record;
BEGIN
    FOR r IN SELECT table_name,constraint_name
             FROM information_schema.constraint_table_usage where constraint_schema not like 'pg_%' and constraint_schema != 'information_schema'
    LOOP
	BEGIN
       EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name)|| ' DROP CONSTRAINT '|| quote_ident(r.constraint_name) || ' CASCADE;';
    EXCEPTION WHEN OTHERS THEN
		-- keep looping
	END;
	END LOOP;
END
$body$;
```

store_id=1 以外のデータをドロップします

```
hub=# delete from rental where rental.staff_id in (select staff.staff_id from staff where staff.store_id <> 1);
DELETE 8004
hub=# delete from payment where payment.staff_id in (select staff_id from staff where staff.store_id <> 1);
DELETE 7304
hub=# delete from inventory where store_id <> 1;
DELETE 2311
hub=# delete from customer where store_id <> 1;
DELETE 273
```

store_1 スキーマ作成

```sql
CREATE SCHEMA store_1;
```

ユーザー作成テーブルを全て public スキーマから store_1 スキーマに移動します

```sql
DO $body$
DECLARE r record;
BEGIN
    FOR r IN SELECT table_name,constraint_name
             FROM information_schema.constraint_table_usage where constraint_schema not like 'pg_%' and constraint_schema != 'information_schema'
    LOOP
       EXECUTE 'ALTER TABLE ' || quote_ident(r.table_name)|| '  SET SCHEMA store_1;';
	END LOOP;
END
$body$;
```

移動チェック

```sql
hub=# SELECT * FROM information_schema.tables WHERE table_schema = 'store_1' limit 10;
```

イイ感じで移動できました。View も自スキーマしか見てないのであれば問題なさそう。

```
 table_catalog | table_schema |         table_name         | table_type | self_referencing_column_name | reference_generation | user_defined_type_catalog | user_defined_type_schema | user_defined_type_name | is_insertable_into | is_typed | commit_action
---------------+--------------+----------------------------+------------+------------------------------+----------------------+---------------------------+--------------------------+------------------------+--------------------+----------+---------------
 hub           | store_1      | actor                      | BASE TABLE |                              |                      |                           |                          |                        | YES                | NO       |  hub           | store_1      | actor_info                 | VIEW       |                              |                      |                           |                          |                        | NO                 | NO       |  hub           | store_1      | customer_list              | VIEW       |                              |                      |                           |                          |                        | NO                 | NO       |  hub           | store_1      | film_list                  | VIEW       |                              |                      |                           |                          |                        | NO                 | NO       |  hub           | store_1      | film                       | BASE TABLE |                              |                      |                           |                          |                        | YES                | NO       |  hub           | store_1      | nicer_but_slower_film_list | VIEW       |                              |                      |                           |                          |                        | NO                 | NO       |  hub           | store_1      | sales_by_film_category     | VIEW       |                              |                      |                           |                          |                        | NO                 | NO       |  hub           | store_1      | store                      | BASE TABLE |                              |                      |                           |                          |                        | YES                | NO       |  hub           | store_1      | sales_by_store             | VIEW       |                              |                      |                           |                          |                        | NO                 | NO       |  hub           | store_1      | staff_list                 | VIEW       |                              |                      |                           |                          |                        | NO                 | NO       | (10 行)
```

ここまでやって思った。
2 店舗目の db を restore したら無に帰す。
スキーマを変更するのではなく、db を変更するべきだった。
dblink 使うか、必要なテーブルの csv ファイルのみエクスポートして取り込むといった方法が考えられる。
今だとロジカルレプリケーションも使えるかもしれない。
