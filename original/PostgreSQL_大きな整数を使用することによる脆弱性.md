# 大きな整数を使用することによる脆弱性

次の記事の内容を抜粋した記事です。  
bigint を超える整数を使用すると、クエリの速度が著しく落ちて、攻撃手段に使用できる場合があるというものです。

https://code.jeremyevans.net/2022-11-01-forcing-sequential-scans-on-postgresql.html

## 発生条件

次の 4 つの質問の回答が`Yes`の場合、脆弱な可能性があります

- 1. PostgreSQL を使用していますか?
- 2. `bigint`範囲外の整数をサポートするプログラミング言語を使用していますか(ほとんどの動的型付けプログラミング言語はサポートします)。
- 3. ユーザー入力から得られた整数値を、範囲内にあるかどうかを検証せずに受け入れているのでしょうか?
- 4. 引用符、明示的なキャスト、またはバインドされた変数を使用せずに、クエリ内で文字通り整数値を使用していますか?

---

※ PostgreSQL が条件に入っているのは、次の仕様によるものです。

> 小数点も指数も含まない数値定数は、その値が型`integer`(32 ビット) に適合する場合、最初は`integer`型であると推定されます。それ以外の場合、その値が型`bigint`(64 ビット)に適合する場合は`bigint`型であるとみなされます。それ以外の場合は、`numeric`型とみなされます。

## 準備

データベース作成

```
postgres@masami-L ~> createdb -U postgres sample
postgres@masami-L ~> psql -U postgres -d sample
```

テーブル作成

```sql
sample=# CREATE TABLE a AS SELECT * FROM generate_series(1,1000000) AS a(id);
CREATE INDEX ON a(id);
SELECT 1000000
CREATE INDEX
```

## 事象

bigint の最大値 9223372036854775807 で 検索

```sql
sample=# EXPLAIN ANALYZE SELECT id FROM a WHERE id = 9223372036854775807;
                                                   QUERY PLAN
-----------------------------------------------------------------------------------------------------------------
 Index Only Scan using a_id_idx on a  (cost=0.42..4.44 rows=1 width=4) (actual time=0.111..0.112 rows=0 loops=1)
   Index Cond: (id = '9223372036854775807'::bigint)
   Heap Fetches: 0
 Planning Time: 0.672 ms
 Execution Time: 0.150 ms
(5 rows)
```

インデックススキャンが使用されます

bigint を超える値で検索します

```sql
sample=# EXPLAIN ANALYZE SELECT id FROM a WHERE id = 9223372036854775808;
                                                    QUERY PLAN
-------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..12175.00 rows=5000 width=4) (actual time=102.700..106.299 rows=0 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on a  (cost=0.00..10675.00 rows=2083 width=4) (actual time=97.138..97.138 rows=0 loops=3)
         Filter: ((id)::numeric = '9223372036854775808'::numeric)
         Rows Removed by Filter: 333333
 Planning Time: 0.469 ms
 Execution Time: 106.355 ms
(8 rows)
```

シーケンシャルスキャンに代わり、動作が 60 倍以上遅くなりました。  
numeric で検索しているため、インデックスが効かないようです。

## 対策

基本的にはクライアントで対策が本筋になります。

- バインド変数を使用する
- パラメータチェックする

`ActiveRecord`等いくつかのデータベースライブラリは、ブログ主の報告をもって、
本事象の対策を取ったようですが、基本的には自前でチェックしたほうがいいでしょう

### その他回避策

何らかの理由でクライアントで対策が取れない場合、 回避策も提案されています

- 予期していない型になるパラメータはエラーにする

```sql
sample=# EXPLAIN ANALYZE SELECT id FROM a WHERE id = 9223372036854775808::bigint;
ERROR:  bigint out of range
```

- numeric のインデックスを張る方法

```sql
sample=# CREATE INDEX ON a((id::numeric));
CREATE INDEX
sample=# EXPLAIN ANALYZE SELECT id FROM a WHERE id = 9223372036854775808;
                                                      QUERY PLAN
----------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on a  (cost=95.17..4805.55 rows=5000 width=4) (actual time=0.108..0.109 rows=0 loops=1)
   Recheck Cond: ((id)::numeric = '9223372036854775808'::numeric)
   ->  Bitmap Index Scan on a_id_idx1  (cost=0.00..93.92 rows=5000 width=0) (actual time=0.104..0.105 rows=0 loops=1)
         Index Cond: ((id)::numeric = '9223372036854775808'::numeric)
 Planning Time: 0.562 ms
 Execution Time: 0.147 ms
(6 rows)
```

ちなみにブログ参照先の Reddit にもあるように整数以外でも当然インデックススキャンはされません。

```sql
sample=# EXPLAIN ANALYZE SELECT id FROM a WHERE id = 0.11;
                                                    QUERY PLAN
-------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..12175.00 rows=5000 width=4) (actual time=97.910..101.180 rows=0 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on a  (cost=0.00..10675.00 rows=2083 width=4) (actual time=92.100..92.101 rows=0 loops=3)
         Filter: ((id)::numeric = 0.11)
         Rows Removed by Filter: 333333
 Planning Time: 0.320 ms
 Execution Time: 101.214 ms
(8 rows)
```
