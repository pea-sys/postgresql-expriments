# GROUP BY 式

GROUP BY 式のバリエーションを次の記事をトレースして試していきます

https://www.cybertec-postgresql.com/en/postgresql-group-by-expression/

データベース準備

```
root@masami-L ~# sudo -i -u postgres
postgres@masami-L:~$ createdb -U postgres sample
postgres@masami-L:~$ psql -U postgres -d sample
```

データ準備

```sql
sample=# create table t_oil (
sample(# region text,
sample(# country text,
sample(# year int,
sample(# production int,
sample(# consumption int
sample(# );
CREATE TABLE
sample=# copy t_oil from program 'curl https://www.cybertec-postgresql.com/secret/oil_ext.txt';
COPY 644
```

### 単純な GROUP BY

基本的な GROUP BY は 2 通りの書き方があります

```sql
sample=# select region, avg(production) from t_oil group by 1;
    region     |          avg
---------------+-----------------------
 North America | 4541.3623188405797101
 Middle East   | 1992.6036866359447005
(2 rows)
```

```sql
sample=# select region, avg(production) from t_oil group by region;
    region     |          avg
---------------+-----------------------
 North America | 4541.3623188405797101
 Middle East   | 1992.6036866359447005
(2 rows)
```

### GROUP BY 式

一般的な式は次のようになります

```sql
sample=# select avg(production) from t_oil where country = 'USA';
          avg
-----------------------
 9141.3478260869565217
(1 row)
```

グループ分けを動的に行うために式を使うこともできます

```sql
sample=# select production > 9000, count(production) from t_oil where country = 'USA' group by production > 9000;
 ?column? | count
----------+-------
 f        |    20
 t        |    26
(2 rows)
```

奇数年と偶数年の行数を数えてます

```sql
sample=# select count(production)
sample-# from t_oil
sample-# where country='USA'
sample-# group by case when year % 2 = 0 then true else false end;
 count
-------
    23
    23
(2 rows)
```

group by の中で sql クエリを使用できる例を示すための例ですが、次のように記載したほうが簡潔です

```sql
sample=# select count(production)
from t_oil
where country='USA'
group by (year % 2 = 0);
 count
-------
    23
    23
(2 rows)
```

group by の中で having も使用できます

```sql
sample=# select count(production) as x
sample-# from t_oil
sample-# where country = 'USA'
sample-# group by year < 1990 having avg(production) > 0;
 x
----
 21
 25
(2 rows)
```

### grouping sets

grouping sets で複数の集計を同時に実行できます

```sql
sample=# select year < 1990, count(production) as x
from t_oil
where country = 'USA'
group by grouping sets (( year < 1990), ());
 ?column? | x
----------+----
          | 46
 f        | 21
 t        | 25
(3 rows)
```

rollup でも同等のクエリが書けます

```Sql
sample=# select year < 1990, count(production) as x
sample-# from t_oil
sample-# where country = 'USA'
sample-# group by rollup (year < 1990);
 ?column? | x
----------+----
          | 46
 f        | 21
 t        | 25
(3 rows)
```
