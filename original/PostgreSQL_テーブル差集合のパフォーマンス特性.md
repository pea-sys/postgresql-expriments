# テーブル差集合のパフォーマンス特性

下記記事のパフォーマンス特性の測定内容です

[テーブル差集合のパフォーマンス](https://github.com/pea-sys/postgresql-expriments/blob/main/original/%E3%83%86%E3%83%BC%E3%83%96%E3%83%AB%E5%B7%AE%E9%9B%86%E5%90%88%E3%81%AE%E3%83%91%E3%83%95%E3%82%A9%E3%83%BC%E3%83%9E%E3%83%B3%E3%82%B9.md)

![303865300-26072b12-6ad4-44e8-a71d-8a1a1cbfd531](https://github.com/pea-sys/postgresql-expriments/assets/49807271/6f4ad460-cd51-4b10-8dad-fcd12c949fbd)

psql Cli から DB 作成後にアクセス

```
root@masami-L ~# createdb -U postgres sample
root@masami-L /# psql -U postgres -d sample
```

データ準備

```sql
sample=# create table t1 (
id serial,
val int default random()*10000000);
CREATE TABLE
sample=# create table t2 (
id serial,
val int default random()*10000000);
CREATE TABLE
sample=# insert into t1
select from generate_series(1,10000000);
INSERT 0 10000000
sample=# insert into t2
select from generate_series(1,10000000);
INSERT 0 10000000
sample=# analyze;
ANALYZE
```

メモリ確保

```sql
postgres=# set work_mem = '512MB';
SET
```

### 「not in」 測定

```sql
sample=# do $$declare
 i int;
 arr bigint[] := array[1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 2000000, 3000000, 4000000, 5000000, 6000000, 7000000, 8000000, 9000
000, 10000000];
 s timestamp;
BEGIN
    FOREACH i IN array arr LOOP
      s := clock_timestamp();
      EXECUTE 'select * from t1 where (val) not in (select val from t2 limit ' || i ||');';
      RAISE INFO '% %', i, clock_timestamp() - s;
   END LOOP;
END$$;
INFO:  1 00:00:02.345145
INFO:  5 00:00:02.346214
INFO:  10 00:00:02.395243
INFO:  50 00:00:02.558942
INFO:  100 00:00:02.528966
INFO:  500 00:00:02.416265
INFO:  1000 00:00:02.431084
INFO:  5000 00:00:02.571213
INFO:  10000 00:00:02.614786
INFO:  50000 00:00:02.820927
INFO:  100000 00:00:03.109624
INFO:  500000 00:00:03.533407
INFO:  1000000 00:00:03.794146
INFO:  2000000 00:00:04.274109
INFO:  3000000 00:00:04.800792
INFO:  4000000 00:00:05.196851
INFO:  5000000 00:00:05.716169
INFO:  6000000 00:00:06.204666
INFO:  7000000 00:00:06.684821
INFO:  8000000 00:00:07.258461
INFO:  9000000 00:00:07.734142
INFO:  10000000 00:00:08.115292
DO
```

### 「not exists」測定

```sql
sample=# do $$declare
 i int;
 arr bigint[] := array[1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 2000000, 3000000, 4000000, 5000000, 6000000, 7000000, 8000000, 9000000, 10000000];
 s timestamp;
BEGIN
    FOREACH i IN array arr LOOP
      s := clock_timestamp();
      EXECUTE 'select * from t1 where not exists (select val from t2 limit ' || i ||');';
      RAISE INFO '% %', i, clock_timestamp() - s;
   END LOOP;
END$$;
INFO:  1 00:00:00.003313
INFO:  5 00:00:00.003196
INFO:  10 00:00:00.003018
INFO:  50 00:00:00.003135
INFO:  100 00:00:00.003116
INFO:  500 00:00:00.003147
INFO:  1000 00:00:00.002981
INFO:  5000 00:00:00.003022
INFO:  10000 00:00:00.003033
INFO:  50000 00:00:00.003068
INFO:  100000 00:00:00.003067
INFO:  500000 00:00:00.002929
INFO:  1000000 00:00:00.003052
INFO:  2000000 00:00:00.003039
INFO:  3000000 00:00:00.003032
INFO:  4000000 00:00:00.003013
INFO:  5000000 00:00:00.003136
INFO:  6000000 00:00:00.003034
INFO:  7000000 00:00:00.003011
INFO:  8000000 00:00:00.002988
INFO:  9000000 00:00:00.003002
INFO:  10000000 00:00:00.002994
DO
```

### 「left join / is NULL」測定

```sql
sample=# do $$declare
 i int;
 arr bigint[] := array[1, 5, 10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000, 500000, 1000000, 2000000, 3000000, 4000000, 5000000, 6000000, 7000000, 8000000, 9000000, 10000000];
 s timestamp;
BEGIN
    FOREACH i IN array arr LOOP
      s := clock_timestamp();
      EXECUTE 'select * from t1 left join (select * from t2 limit ' || i ||') as t using (val) where t.val is NUL
L;';
      RAISE INFO '% %', i, clock_timestamp() - s;
   END LOOP;
END$$;
INFO:  1 00:00:02.872178
INFO:  5 00:00:02.840261
INFO:  10 00:00:02.843077
INFO:  50 00:00:02.851021
INFO:  100 00:00:02.863154
INFO:  500 00:00:02.948286
INFO:  1000 00:00:03.04639
INFO:  5000 00:00:03.059086
INFO:  10000 00:00:03.149823
INFO:  50000 00:00:03.614661
INFO:  100000 00:00:03.902975
INFO:  500000 00:00:04.56271
INFO:  1000000 00:00:04.747579
INFO:  2000000 00:00:05.099058
INFO:  3000000 00:00:05.206775
INFO:  4000000 00:00:05.658422
INFO:  5000000 00:00:05.666181
INFO:  6000000 00:00:06.027143
INFO:  7000000 00:00:06.348277
INFO:  8000000 00:00:06.326723
INFO:  9000000 00:00:06.331048
INFO:  10000000 00:00:08.122132
DO
```

### 「except all」測定

```sql
postgres=# do $$declare
 i int;
 arr bigint[] := array[1, 5, 10, 50, 100, 500, 1000, 5000, 10000,50000,100000,500000, 1000000, 2000000, 3000000, 4000000, 5000000, 60000000, 7000000, 8000000, 9000000, 10000000];
 s timestamp;
BEGIN
    FOREACH i IN array arr LOOP
      s := clock_timestamp();
      EXECUTE 'select * from t1 except all (select * from t2 limit ' || i || ');';
      RAISE INFO '% %', i, clock_timestamp() - s;
   END LOOP;
END$$;
INFO:  1 00:00:07.644083
INFO:  5 00:00:07.682577
INFO:  10 00:00:07.738055
INFO:  50 00:00:07.730405
INFO:  100 00:00:07.753818
INFO:  500 00:00:07.707652
INFO:  1000 00:00:07.679489
INFO:  5000 00:00:07.647736
INFO:  10000 00:00:07.854194
INFO:  50000 00:00:07.805739
INFO:  100000 00:00:07.796277
INFO:  500000 00:00:07.882429
INFO:  1000000 00:00:08.017805
INFO:  2000000 00:00:08.344908
INFO:  3000000 00:00:08.644733
INFO:  4000000 00:00:08.962535
INFO:  5000000 00:00:09.014839
INFO:  60000000 00:00:10.564767
INFO:  7000000 00:00:09.627133
INFO:  8000000 00:00:09.930009
INFO:  9000000 00:00:10.143857
INFO:  10000000 00:00:10.412141
DO
```
