# Random

次の記事をトレースします。  
https://www.crunchydata.com/blog/rolling-the-dice-with-postgres-random-function

---

■ 一様分布

```sql
postgres=# \o test.txt
postgres=# SELECT random() FROM generate_series(1, 1000000);

```

```
         random
------------------------
     0.5121269713926158
     0.6005537213286272
    0.31048427871277706
・・・

```

[散布図]  
 ![1](https://github.com/pea-sys/postgresql-expriments/assets/49807271/a6ce1b90-0005-4ad2-bdab-64d883552038)

■ 正数で一様分布

```sql
postgres=# \o test.txt
postgres=# SELECT ceil(10 * random()) FROM generate_series(1, 1000000);
```

[散布図]  
![2](https://github.com/pea-sys/postgresql-expriments/assets/49807271/5da53a79-829e-4bb8-b732-24da09adccfc)

0~9 の値域にした場合は ceil ではなく、floor を使用します

■ ランダムな行と値

乱数として扱う列にインデックスを貼ると速度アップが見込める

```sql
postgres=# CREATE TABLE fruits (
postgres(#   id SERIAL PRIMARY KEY,
postgres(#   fruit TEXT NOT NULL,
postgres(#   random FLOAT8 DEFAULT random()
postgres(#   );
CREATE TABLE
postgres=#
postgres=# INSERT INTO fruits (fruit)
postgres-#   VALUES ('apple'),('banana'),('cherry'),('pear'),('peach');
INSERT 0 5
postgres=#
postgres=# CREATE INDEX fruits_random_x ON fruits (random);
CREATE INDEX
```

行数が少ないテーブルなら以下でも OK

```sql
postgres=# SELECT *
postgres-# FROM fruits
postgres-# ORDER BY random()
postgres-# LIMIT 1;
 id | fruit |       random
----+-------+--------------------
  5 | peach | 0.5486546807195751
(1 行)
```

■ ランダムグループ
ランダムにグループ分けします

```sql
postgres=# WITH random_fruits AS (
postgres(#     SELECT id, fruit
postgres(#     FROM fruits
postgres(#     ORDER BY random()
postgres(# )
postgres-# SELECT row_number() over () % 2 AS group,
postgres-#        id, fruit
postgres-# FROM random_fruits
postgres-# ORDER BY 1;
 group | id | fruit
-------+----+--------
     0 |  2 | banana
     0 |  5 | peach
     1 |  3 | cherry
     1 |  1 | apple
     1 |  4 | pear
(5 行)
```

■ 正規分布

```sql
postgres=# \o test.txt
postgres=# SELECT random_normal() FROM generate_series(1, 1000000);
```

分布を確認するために bin に分けます

```sql
postgres=# SELECT random_normal()::integer,
postgres-#        Count(*)
postgres-# FROM generate_series(1,1000)
postgres-# GROUP BY 1
postgres-# ORDER BY 1;
 random_normal | count
---------------+-------
            -3 |     9
            -2 |    69
            -1 |   252
             0 |   369
             1 |   245
             2 |    48
             3 |     8
```
