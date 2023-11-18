# PostgreSQLのサンプルデータベース



## ■World
世界の地理情報や人口データベース  
データ量は五千行程度  

### ソース
[https://www.postgresql.org/ftp/projects/pgFoundry/dbsamples/](https://www.postgresql.org/ftp/projects/pgFoundry/dbsamples/world/)

### リストア

```sql
createdb -U postgres world
psql -U postgres -f ./world.sql world
```
### ER図
![world](https://github.com/pea-sys/postgresql-expriments/assets/49807271/ead6b552-d4fa-489f-9814-5ff888635139)

-------------------------------------

## ■usda
米国農務省農業研究局。 2005. USDA 標準参照用栄養データベース、リリース 18。栄養データ研究所ホームページ、http://www.ars.usda.gov/ba/bhnrc/ndl  
データ量は三十五万行程度  

### ソース
https://www.postgresql.org/ftp/projects/pgFoundry/dbsamples/usda/usda-r18-1.0/


### リストア
```sql
createdb -U postgres usda
psql -U postgres -f usda.sql usda
```

### ER図
![usda](https://github.com/pea-sys/postgresql-expriments/assets/49807271/5d59e22d-9032-4d51-afb7-6bc24b55dcad)

-----------------
## ■dvdrental 
DVD連らるショップのDB  
後述のpagillaをシンプルにしたもの

### ソース
https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/  
約4万5千行

### リストア
```sql
createdb -U postgres dvdrental
pg_restore -h localhost -p 5432 -U postgres -d dvdrental dvdrental.tar
```

### ER図
![dvd-rental-sample-database-diagram](https://github.com/pea-sys/postgresql-expriments/assets/49807271/aa84e99b-e0be-4f02-966b-232e2dadc265)
※ホームページより抜粋

-----------------
## ■pagilla 
DVDレンタルショップのDB  
https://www.postgresqltutorial.com/postgresql-getting-started/postgresql-sample-database/

### ソース
https://www.postgresql.org/ftp/projects/pgFoundry/dbsamples/pagila/pagila/

### リストア
```sql
createdb -U postgres pagilla
psql -U postgres -f pagila-schema.sql pagilla
psql -U postgres -f pagila-insert-data.sql pagilla
psql -U postgres -f pagila-data.sql pagilla
```
### ER図
複雑で汚い図しか出ないので省略



-----------------
## ■iso
国際標準化機構 (ISO) が国名およびそれに準ずる区域、都道府県や州といった地域のために割り振った地理情報の符号化  
約五千行

### ソース
https://www.postgresql.org/ftp/projects/pgFoundry/dbsamples/iso-3166/iso-3166-1.0/

### リストア
```sql
createdb -U postgres iso
psql -U postgres -f iso-3166.sql iso
```

### ER図
![Untitled](https://github.com/pea-sys/postgresql-expriments/assets/49807271/03a9319e-0e2f-4df8-8917-425cb3baf92e)

-----------------
## ■french-towns-communes-francaises
フランスの町、コミューン  
約三万五千行


### ソース
https://www.postgresql.org/ftp/projects/pgFoundry/dbsamples/french-towns-communes-francais/french-towns-communes-francaises-1.0/


### リストア
```sql
createdb -U postgres french-towns-communes-francaises
psql -U postgres -f french-towns-communes-francaises.sql french-towns-communes-francaises
```

### ER図
![Untitled (1)](https://github.com/pea-sys/postgresql-expriments/assets/49807271/b9c3e60b-a614-4fff-b501-bb69c34f9374)

------------------
## ■dellstone
Dell DVD ストア
約17万行

### ソース
https://linux.dell.com/dvdstore/

### リストア
```sql
createdb -U postgres dellstore
psql -U postgres -f dellstore2-normal-1.0.sql dellstore
```

### ER図
![Untitled](https://github.com/pea-sys/postgresql-expriments/assets/49807271/42a4e79a-c717-4ecf-b76f-f2ace98a24ab)

------------------
## ■bitcoin
bitcoinの取引データ  
1テーブルの時系列データ  
約240万行

### ソース
https://docs.timescale.com/tutorials/latest/blockchain-query/blockchain-dataset/  
※アカウント登録が必要

### リストア
```sql
CREATE TABLE transactions (
   time TIMESTAMPTZ,
   block_id INT,
   hash TEXT,
   size INT,
   weight INT,
   is_coinbase BOOLEAN,
   output_total BIGINT,
   output_total_usd DOUBLE PRECISION,
   fee BIGINT,
   fee_usd DOUBLE PRECISION,
   details JSONB
);
CREATE INDEX hash_idx ON public.transactions USING HASH (hash);
CREATE INDEX block_idx ON public.transactions (block_id);
CREATE UNIQUE INDEX time_hash_idx ON public.transactions (time, hash);
```

### ER図
![Untitled](https://github.com/pea-sys/postgres-datasets/assets/49807271/d841f157-c2be-48b4-b6d7-6023bafcc73c)

------------------
## ■pgbench
ベンチーマークのために用意されているデータ  
約10万行(ベンチを動かすことで調整可)

### リストア
```
createdb -U postgres bench
pgbench -U postgres -i bench
```
### ER図
![1](https://github.com/pea-sys/postgresql-expriments/assets/49807271/015c9ab7-bca7-4f7b-8ff9-db1dca8d668d)
