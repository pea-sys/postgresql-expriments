# `LATERAL JOIN` のパフォーマンス

`LATERAL JOIN` のパフォーマンスを測定します

次の記事を勉強目的でトレースしてます  
※古めの記事なので postgres のバージョンも古いです

https://amandasposito.com/postgresql/performance/2021/01/04/postgres-lateral-join.html

---

DB 作成

```sql
createdb -U postgres sample
psql -U postgres -d sample
```

バージョン確認

```sql
sample=# select version();
                          version
------------------------------------------------------------
 PostgreSQL 16.2, compiled by Visual C++ build 1937, 64-bit
(1 行)
```

### ■ トップ N の取得

タグ別に最新の映画を取り出すケースを考えます

テーブル作成

```sql
CREATE TABLE tags (
  id serial PRIMARY KEY,
  name VARCHAR(255)
);

CREATE TABLE movies (
  id serial PRIMARY KEY,
  name VARCHAR(255),
  tag_id int NOT NULL,
  created_at timestamp NOT NULL DEFAULT NOW(),
  FOREIGN KEY (tag_id) REFERENCES tags(id) ON UPDATE CASCADE
);

CREATE INDEX movies_tag_id_index ON movies (tag_id);
```

テストデータの挿入

```Sql
-- Genres
INSERT INTO "tags"("name") VALUES('Action');
INSERT INTO "tags"("name") VALUES('Animation');
INSERT INTO "tags"("name") VALUES('Sci-Fi');

-- Movies
INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('The Matrix', (SELECT id FROM "tags" where "name" = 'Action'), '1999-05-21');
INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('Tenet', (SELECT id FROM "tags" where "name" = 'Action'), '2020-10-29');
INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('Wonder Woman 1984', (SELECT id FROM "tags" where "name" = 'Action'), '2020-12-25');

INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('Toy Story', (SELECT id FROM "tags" where "name" = 'Animation'), '1995-12-22');
INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('Monsters Inc.', (SELECT id FROM "tags" where "name" = 'Animation'), '2001-11-14');
INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('Finding Nemo', (SELECT id FROM "tags" where "name" = 'Animation'), '2003-07-4');

INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('Arrival', (SELECT id FROM "tags" where "name" = 'Sci-Fi'), '2016-10-24');
INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('Minority Report', (SELECT id FROM "tags" where "name" = 'Sci-Fi'), '2002-08-02');
INSERT INTO "movies"("name", "tag_id", "created_at") VALUES('The Midnight Sky', (SELECT id FROM "tags" where "name" = 'Sci-Fi'), '2020-12-23');
```

### ■`ROW NUMBER` を使う解決方法

`LATERAL`を使わないケース
各タグごとに最新順でソートするクエリを動作確認します。  
ランキングを得るために `ROW_NUMBER` を使用します。

```sql
sample=# SELECT
sample-#   tag_id,
sample-#   name,
sample-#   created_at,
sample-#   ROW_NUMBER() OVER(PARTITION BY tag_id ORDER BY tag_id, created_at DESC)
sample-# FROM movies;
 tag_id |       name        |     created_at      | row_number
--------+-------------------+---------------------+------------
      1 | Wonder Woman 1984 | 2020-12-25 00:00:00 |          1
      1 | Tenet             | 2020-10-29 00:00:00 |          2
      1 | The Matrix        | 1999-05-21 00:00:00 |          3
      2 | Finding Nemo      | 2003-07-04 00:00:00 |          1
      2 | Monsters Inc.     | 2001-11-14 00:00:00 |          2
      2 | Toy Story         | 1995-12-22 00:00:00 |          3
      3 | The Midnight Sky  | 2020-12-23 00:00:00 |          1
      3 | Arrival           | 2016-10-24 00:00:00 |          2
      3 | Minority Report   | 2002-08-02 00:00:00 |          3
(9 行)
```

ランキングが不要なら下記クエリで OK

```sql
sample=# SELECT
sample-#   tag_id,
sample-#   name,
sample-#   created_at
sample-# FROM movies ORDER BY tag_id,created_at desc;
 tag_id |       name        |     created_at
--------+-------------------+---------------------
      1 | Wonder Woman 1984 | 2020-12-25 00:00:00
      1 | Tenet             | 2020-10-29 00:00:00
      1 | The Matrix        | 1999-05-21 00:00:00
      2 | Finding Nemo      | 2003-07-04 00:00:00
      2 | Monsters Inc.     | 2001-11-14 00:00:00
      2 | Toy Story         | 1995-12-22 00:00:00
      3 | The Midnight Sky  | 2020-12-23 00:00:00
      3 | Arrival           | 2016-10-24 00:00:00
      3 | Minority Report   | 2002-08-02 00:00:00
(9 行)
```

今回はランキング 2 位までが必要なので、クエリをそのように書き換えます。

```sql
sample=# with movies_by_tags (tag_id, name, created_at, rank) as (
sample(#   SELECT
sample(#     tag_id,
sample(#     name,
sample(#     created_at,
sample(#     ROW_NUMBER() OVER(PARTITION BY tag_id ORDER BY tag_id, created_at DESC)
sample(#   FROM movies
sample(# )
sample-# select *
sample-# from movies_by_tags mbt
sample-# where mbt.rank < 3;
 tag_id |       name        |     created_at      | rank
--------+-------------------+---------------------+------
      1 | Wonder Woman 1984 | 2020-12-25 00:00:00 |    1
      1 | Tenet             | 2020-10-29 00:00:00 |    2
      2 | Finding Nemo      | 2003-07-04 00:00:00 |    1
      2 | Monsters Inc.     | 2001-11-14 00:00:00 |    2
      3 | The Midnight Sky  | 2020-12-23 00:00:00 |    1
      3 | Arrival           | 2016-10-24 00:00:00 |    2
(6 行)
```

### ■`LATERAL` を使う解決方法

`LATERAL` 句でも同じ結果が得られます

```sql
sample=# SELECT *
sample-# FROM tags t
sample-# JOIN LATERAL (
sample(#   SELECT m.*
sample(#   FROM movies m
sample(#   WHERE m.tag_id = t.id
sample(#   ORDER BY m.created_at DESC
sample(#   FETCH FIRST 2 ROWS ONLY
sample(# ) e1 ON true;
 id |   name    | id |       name        | tag_id |     created_at
----+-----------+----+-------------------+--------+---------------------
  1 | Action    |  3 | Wonder Woman 1984 |      1 | 2020-12-25 00:00:00
  1 | Action    |  2 | Tenet             |      1 | 2020-10-29 00:00:00
  2 | Animation |  6 | Finding Nemo      |      2 | 2003-07-04 00:00:00
  2 | Animation |  5 | Monsters Inc.     |      2 | 2001-11-14 00:00:00
  3 | Sci-Fi    |  9 | The Midnight Sky  |      3 | 2020-12-23 00:00:00
  3 | Sci-Fi    |  7 | Arrival           |      3 | 2016-10-24 00:00:00
(6 行)
```

### ■ 両ソリューションのパフォーマンスを比較する

- `ROW NUMBER` 使用(9 レコード)

```sql
sample=# explain analyze
sample-# with movies_by_tags (tag_id, name, created_at, rank) as (
sample(#   SELECT
sample(#     tag_id,
sample(#     name,
sample(#     created_at,
sample(#     ROW_NUMBER() OVER(PARTITION BY tag_id ORDER BY tag_id, created_at DESC)
sample(#   FROM movies
sample(# )
sample-# select *
sample-# from movies_by_tags mbt
sample-# where mbt.rank < 3;
                                                   QUERY PLAN
-----------------------------------------------------------------------------------------------------------------
 WindowAgg  (cost=16.39..19.54 rows=140 width=536) (actual time=0.056..0.065 rows=6 loops=1)
   Run Condition: (row_number() OVER (?) < 3)
   ->  Sort  (cost=16.39..16.74 rows=140 width=528) (actual time=0.047..0.048 rows=9 loops=1)
         Sort Key: movies.tag_id, movies.created_at DESC
         Sort Method: quicksort  Memory: 25kB
         ->  Seq Scan on movies  (cost=0.00..11.40 rows=140 width=528) (actual time=0.026..0.028 rows=9 loops=1)
 Planning Time: 0.198 ms
 Execution Time: 0.131 ms
(8 行)
```

- `LATERAL` 使用(9 レコード)

```Sql
sample=# explain analyze
sample-# SELECT *
sample-# FROM tags t
sample-# JOIN LATERAL (
sample(#   SELECT m.*
sample(#   FROM movies m
sample(#   WHERE m.tag_id = t.id
sample(#   ORDER BY m.created_at DESC
sample(#   FETCH FIRST 2 ROWS ONLY
sample(# ) e1 ON true;
                                                                    QUERY PLAN

--------------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=2.37..345.65 rows=140 width=1052) (actual time=0.052..0.070 rows=6 loops=1)
   ->  Seq Scan on tags t  (cost=0.00..11.40 rows=140 width=520) (actual time=0.022..0.023 rows=3 loops=1)
   ->  Limit  (cost=2.37..2.38 rows=1 width=532) (actual time=0.013..0.013 rows=2 loops=3)
         ->  Sort  (cost=2.37..2.38 rows=1 width=532) (actual time=0.011..0.012 rows=2 loops=3)
               Sort Key: m.created_at DESC
               Sort Method: quicksort  Memory: 25kB
               ->  Index Scan using movies_tag_id_index on movies m  (cost=0.14..2.36 rows=1 width=532) (actual time=0.006..0.007 rows=3 loops=3)
                     Index Cond: (tag_id = t.id)
 Planning Time: 0.250 ms
 Execution Time: 0.110 ms
(10 行)
```

双方十分に早いクエリですが、元ブログとは異なり LATERAL ありの方が、僅かに遅くなりました。
データが少ないので、さらに増やして比較します。

```sql
sample=# -- Generates 3_000_000 movies
sample=# INSERT INTO "movies"("name", "tag_id")
sample-# SELECT
sample-#    generate_series(1,1000000) as "name",
sample-#    (SELECT id FROM "tags" where "name" = 'Action')
sample-# ;
INSERT 0 1000000
sample=#
sample=# INSERT INTO "movies"("name", "tag_id")
sample-# SELECT
sample-#    generate_series(1,1000000) as "name",
sample-#    (SELECT id FROM "tags" where "name" = 'Animation')
sample-# ;
INSERT 0 1000000
sample=#
sample=# INSERT INTO "movies"("name", "tag_id")
sample-# SELECT
sample-#    generate_series(1,1000000) as "name",
sample-#    (SELECT id FROM "tags" where "name" = 'Sci-Fi')
sample-# ;
INSERT 0 1000000
sample=# vacuum analyze;
VACUUM
```

- ROW NUMBER 使用(300 万レコード)

```sql
sample=# explain analyze
sample-# with movies_by_tags (tag_id, name, created_at, rank) as (
sample(#   SELECT
sample(#     tag_id,
sample(#     name,
sample(#     created_at,
sample(#     ROW_NUMBER() OVER(PARTITION BY tag_id ORDER BY tag_id, created_at DESC)
sample(#   FROM movies
sample(# )
sample-# select *
sample-# from movies_by_tags mbt
sample-# where mbt.rank < 3
sample-# ;
                                                                        QUERY PLAN

-----------------------------------------------------------------------------------------------------------------------------------------------------------
 WindowAgg  (cost=145910.14..535229.91 rows=3000009 width=26) (actual time=568.540..2300.790 rows=6 loops=1)
   Run Condition: (row_number() OVER (?) < 3)
   ->  Incremental Sort  (cost=145910.14..475229.73 rows=3000009 width=18) (actual time=568.515..2084.742 rows=3000009 loops=1)
         Sort Key: movies.tag_id, movies.created_at DESC
         Presorted Key: movies.tag_id
         Full-sort Groups: 3  Sort Method: quicksort  Average Memory: 28kB  Peak Memory: 28kB
         Pre-sorted Groups: 3  Sort Method: external merge  Average Disk: 32168kB  Peak Disk: 32168kB
         ->  Index Scan using movies_tag_id_index on movies  (cost=0.43..66677.06 rows=3000009 width=18) (actual time=0.015..686.332 rows=3000009 loops=1)
 Planning Time: 3.686 ms
 Execution Time: 2308.481 ms
(10 行)
```

![explain_plan_1721006273185](https://github.com/user-attachments/assets/bd17b4ad-8882-4685-87e2-ea3465259751)

- LATERAL 使用(300 万レコード)

```sql
sample=# explain analyze
sample-# SELECT *
sample-# FROM tags t
sample-# JOIN LATERAL (
sample(#   SELECT m.*
sample(#   FROM movies m
sample(#   WHERE m.tag_id = t.id
sample(#   ORDER BY m.created_at DESC
sample(#   FETCH FIRST 2 ROWS ONLY
sample(# ) e1 ON true
sample-# ;
                                                                            QUERY PLAN

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=34726.41..4861712.65 rows=280 width=542) (actual time=237.432..703.101 rows=6 loops=1)
   ->  Seq Scan on tags t  (cost=0.00..11.40 rows=140 width=520) (actual time=0.039..0.043 rows=3 loops=1)
   ->  Limit  (cost=34726.41..34726.42 rows=2 width=22) (actual time=234.345..234.346 rows=2 loops=3)
         ->  Sort  (cost=34726.41..37226.42 rows=1000003 width=22) (actual time=234.340..234.341 rows=2 loops=3)
               Sort Key: m.created_at DESC
               Sort Method: top-N heapsort  Memory: 25kB
               ->  Index Scan using movies_tag_id_index on movies m  (cost=0.43..24726.38 rows=1000003 width=22) (actual time=0.019..128.566 rows=1000003 loops=3)
                     Index Cond: (tag_id = t.id)
 Planning Time: 2.058 ms
 Execution Time: 703.154 ms
(10 行)
```

![explain_plan_1721006251842](https://github.com/user-attachments/assets/946bed4c-7191-43db-a53b-c33e7ff61a73)

300 万レコードでは `LATERAL` の方が速くなりました。  
PostgreSQL の旧バージョンだと`ROW NUMBER`を使ったクエリの実行計画では`Index Scan`は使用されていませんでしたが、PostgreSQL16 以降だと使用されるようになっており、パフォーマンスの差が縮まっています。  
ただし、`external merge`はディスク I/O が発生するため、テーブルサイズが増えれば増えるほどに`ROW NUMBER`が相対的に遅くなるでしょう。

`work_mem`の設定値を増やすことでディスク I/O は軽減できますが、基本的に`ROW NUMBER`を使うクエリはスケールしないので使わない方が良いでしょう

- 元ブログ計測値(2021 年時点で使用できる PostgreSQL バージョン)

|              | 9 レコード | 300 万レコード |
| ------------ | ---------- | -------------- |
| `ROW NUMBER` | 0.35 秒    | 8.5 秒         |
| `LATERAL`    | 0.22 秒    | 0.9 約         |

- 自分の実行環境(PostgreSQL 16)  
  ※バージョン以外にマシンスペックや設定も恐らく異なる

|              | 9 レコード | 300 万レコード |
| ------------ | ---------- | -------------- |
| `ROW NUMBER` | 0.33 秒    | 2.3 秒         |
| `LATERAL`    | 0.36 秒    | 0.7 約         |

とあるテーブルの値を元にビッグテーブルの集計を行う場合は、
`LATERAL`はスケールするので便利ですね。

### ■ ディスク I/O の確認(消化不良)

試しに、統計情報を確認します
統計情報をリセット後、各クエリ実行後の統計情報を確認します

※共有バッファやディスクキャッシュが使われないように念のため、OS 再起動して測定。

- `ROW NUMBER()`

```sql
sample=# select pg_stat_reset_shared('io');
 pg_stat_reset_shared
----------------------

(1 行)
sample=# select stats_reset from pg_stat_io where context in ('normal','bulkread') and backend_type='client backend' limit 1;
          stats_reset
-------------------------------
 2024-07-15 15:56:33.399068+09
(1 行)

sample=# explain analyze
sample-#  with movies_by_tags (tag_id, name, created_at, rank) as (
sample(#    SELECT
sample(#      tag_id,
sample(#      name,
sample(#      created_at,
sample(#      ROW_NUMBER() OVER(PARTITION BY tag_id ORDER BY tag_id, created_at DESC)
sample(#    FROM movies
sample(#  )
sample-#  select *
sample-#  from movies_by_tags mbt
sample-#  where mbt.rank < 3
sample-#  ;
                                                                         QUERY PLAN

------------------------------------------------------------------------------------------------------------------------------------------------------------
 WindowAgg  (cost=145910.14..535229.91 rows=3000009 width=26) (actual time=878.991..4115.234 rows=6 loops=1)
   Run Condition: (row_number() OVER (?) < 3)
   ->  Incremental Sort  (cost=145910.14..475229.73 rows=3000009 width=18) (actual time=860.132..3741.449 rows=3000009 loops=1)
         Sort Key: movies.tag_id, movies.created_at DESC
         Presorted Key: movies.tag_id
         Full-sort Groups: 3  Sort Method: quicksort  Average Memory: 28kB  Peak Memory: 28kB
         Pre-sorted Groups: 3  Sort Method: external merge  Average Disk: 32168kB  Peak Disk: 32168kB
         ->  Index Scan using movies_tag_id_index on movies  (cost=0.43..66677.06 rows=3000009 width=18) (actual time=0.919..1671.303 rows=3000009 loops=1)
 Planning Time: 23.303 ms
 Execution Time: 4123.651 ms
(10 行)


sample=# vacuum analyze;
VACUUM
sample=# select * from pg_stat_io where context in ('normal','bulkread') and backend_type='client backend';
  backend_type  |    object     | context  | reads | read_time | writes | write_time | writebacks | writeback_time | extends | extend_time | op_bytes | hits | evictions | reuses | fsyncs | fsync_time |          stats_reset
----------------+---------------+----------+-------+-----------+--------+------------+------------+----------------+---------+-------------+----------+------+-----------+--------+--------+------------+-------------------------------
 client backend | relation      | bulkread |     0 |         0 |      0 |          0 |          0 |              0 |         |             |     8192 |    0 |         0 |      0 |        |            | 2024-07-15 16:09:34.541202+09
 client backend | relation      | normal   | 21892 |         0 |      0 |          0 |          0 |              0 |       0 |           0 |     8192 | 9239 |         0 |        |      0 |          0 | 2024-07-15 16:09:34.541202+09
 client backend | temp relation | normal   |     0 |         0 |      0 |          0 |            |                |       0 |           0 |     8192 |    0 |         0 |        |        |            | 2024-07-15 16:09:34.541202+09
(3 行)


```

- `LATELAL JOIN`

```sql
sample=# select pg_stat_reset_shared('io');
 pg_stat_reset_shared
----------------------

(1 行)


sample=# select stats_reset from pg_stat_io where context in ('normal','bulkread') and backend_type='client backend' limit 1;
          stats_reset
-------------------------------
 2024-07-15 16:23:26.631774+09
(1 行)

sample=#  explain analyze
sample-#   SELECT *
sample-#   FROM tags t
sample-#   JOIN LATERAL (
sample(#     SELECT m.*
sample(#     FROM movies m
sample(#     WHERE m.tag_id = t.id
sample(#     ORDER BY m.created_at DESC
sample(#     FETCH FIRST 2 ROWS ONLY
sample(#   ) e1 ON true
sample-#   ;
                                                                            QUERY PLAN

-------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Nested Loop  (cost=34729.01..104188.12 rows=6 width=34) (actual time=623.355..1497.145 rows=6 loops=1)
   ->  Seq Scan on tags t  (cost=0.00..1.03 rows=3 width=12) (actual time=0.353..0.357 rows=3 loops=1)
   ->  Limit  (cost=34729.01..34729.01 rows=2 width=22) (actual time=498.921..498.922 rows=2 loops=3)
         ->  Sort  (cost=34729.01..37229.01 rows=1000003 width=22) (actual time=498.916..498.917 rows=2 loops=3)
               Sort Key: m.created_at DESC
               Sort Method: top-N heapsort  Memory: 25kB
               ->  Index Scan using movies_tag_id_index on movies m  (cost=0.43..24728.98 rows=1000003 width=22) (actual time=3.597..364.720 rows=1000003 loops=3)
                     Index Cond: (tag_id = t.id)
 Planning Time: 35.839 ms
 Execution Time: 1498.190 ms
(10 行)


sample=# vacuum analyze;
VACUUM
sample=# select * from pg_stat_io where context in ('normal','bulkread') and backend_type='client backend';
  backend_type  |    object     | context  | reads | read_time | writes | write_time | writebacks | writeback_time | extends | extend_time | op_bytes | hits | evictions | reuses | fsyncs | fsync_time |          stats_reset
----------------+---------------+----------+-------+-----------+--------+------------+------------+----------------+---------+-------------+----------+------+-----------+--------+--------+------------+-------------------------------
 client backend | relation      | bulkread |     0 |         0 |      0 |          0 |          0 |              0 |         |             |     8192 |    0 |         0 |      0 |        |            | 2024-07-15 16:23:26.631774+09
 client backend | relation      | normal   | 21900 |         0 |      0 |          0 |          0 |              0 |       0 |           0 |     8192 | 9340 |         0 |        |      0 |          0 | 2024-07-15 16:23:26.631774+09
 client backend | temp relation | normal   |     0 |         0 |      0 |          0 |            |                |       0 |           0 |     8192 |    0 |         0 |        |        |            | 2024-07-15 16:23:26.631774+09
(3 行)
```

`ROW NUMBER`は external merge により、`LATERAL`よりディスク読み込みが多くなると考えましたが、
実際にはほとんど同じ結果になりました。  
では、ここまでパフォーマンスの差を生み出したのはなんだろうという疑問が残ってしまいました。
