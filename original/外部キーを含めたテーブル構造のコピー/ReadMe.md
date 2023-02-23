# 外部キーを含めたテーブル構造のコピー

StackOverFlow で表題の方法が記載されており、役立つ場面がありそうだなと思ったため、試してみる。

[引用]  
https://stackoverflow.com/questions/23693873/how-to-copy-structure-of-one-table-to-another-with-foreign-key-constraints-in-ps

1.以下のデータベースをリストアします。  
https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/

```
psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE dvdrental TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'C' LC_CTYPE = 'C';"
pg_restore -U postgres -d dvdrental ./dvdrental.tar
```

2.テーブル構造をコピーする関数を追加します(pgAdmin で実行)。

```sql
create or replace function create_table_like(source_table text, new_table text)
returns void language plpgsql
as $$
declare
    rec record;
begin
    execute format(
        'create table %s (like %s including all)',
        new_table, source_table);
    for rec in
        select oid, conname
        from pg_constraint
        where contype = 'f'
        and conrelid = source_table::regclass
    loop
        execute format(
            'alter table %s add constraint %s %s',
            new_table,
            replace(rec.conname, source_table, new_table),
            pg_get_constraintdef(rec.oid));
    end loop;
end $$;
```

3.外部キーを持っている customer テーブルの構造を customer_bak テーブルにコピーします。

```sql
select create_table_like('customer', 'customer_bak');
```

4.テーブル構造を確認します

■customer

```sql
dvdrental=# \d customer
                                              テーブル"public.customer"
     列      |           タイプ            | 照合順序 | Null 値を許容 |                  デフォルト
-------------+-----------------------------+----------+---------------+-----------------------------------------------
 customer_id | integer                     |          | not null      | nextval('customer_customer_id_seq'::regclass)
 store_id    | smallint                    |          | not null      |
 first_name  | character varying(45)       |          | not null      |
 last_name   | character varying(45)       |          | not null      |
 email       | character varying(50)       |          |               |
 address_id  | smallint                    |          | not null      |
 activebool  | boolean                     |          | not null      | true
 create_date | date                        |          | not null      | 'now'::text::date
 last_update | timestamp without time zone |          |               | now()
 active      | integer                     |          |               |
インデックス:
    "customer_pkey" PRIMARY KEY, btree (customer_id)
    "idx_fk_address_id" btree (address_id)
    "idx_fk_store_id" btree (store_id)
    "idx_last_name" btree (last_name)
外部キー制約:
    "customer_address_id_fkey" FOREIGN KEY (address_id) REFERENCES address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT
参照元:
    TABLE "payment" CONSTRAINT "payment_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT
    TABLE "rental" CONSTRAINT "rental_customer_id_fkey" FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON UPDATE CASCADE ON DELETE RESTRICT
トリガー:
    last_updated BEFORE UPDATE ON customer FOR EACH ROW EXECUTE FUNCTION last_updated()
```

■customer_bak

```sql
dvdrental=# \d customer_bak
                                            テーブル"public.customer_bak"
     列      |           タイプ            | 照合順序 | Null 値を許容 |                  デフォルト
-------------+-----------------------------+----------+---------------+-----------------------------------------------
 customer_id | integer                     |          | not null      | nextval('customer_customer_id_seq'::regclass)
 store_id    | smallint                    |          | not null      |
 first_name  | character varying(45)       |          | not null      |
 last_name   | character varying(45)       |          | not null      |
 email       | character varying(50)       |          |               |
 address_id  | smallint                    |          | not null      |
 activebool  | boolean                     |          | not null      | true
 create_date | date                        |          | not null      | 'now'::text::date
 last_update | timestamp without time zone |          |               | now()
 active      | integer                     |          |               |
インデックス:
    "customer_bak_pkey" PRIMARY KEY, btree (customer_id)
    "customer_bak_address_id_idx" btree (address_id)
    "customer_bak_last_name_idx" btree (last_name)
    "customer_bak_store_id_idx" btree (store_id)
外部キー制約:
    "customer_bak_address_id_fkey" FOREIGN KEY (address_id) REFERENCES address(address_id) ON UPDATE CASCADE ON DELETE RESTRICT

```

良さそうですね。
