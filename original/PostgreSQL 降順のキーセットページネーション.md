# 降順のキーセットページネーション

こちらの記事のトレース

https://www.cybertec-postgresql.com/en/keyset-pagination-with-descending-order/

ページ分割クエリのサンプルテーブル

```sql
sample=# CREATE TABLE sortme (
sample(#    id bigint PRIMARY KEY,
sample(#    val1 integer NOT NULL,
sample(#    val2 timestamp with time zone NOT NULL,
sample(#    val3 text NOT NULL
sample(# );
CREATE TABLE
sample=# -- deterministic, but sort of random values
sample=# INSERT INTO sortme
sample-# SELECT i,
sample-#        abs(hashint8(i)) % 200 + 1,
sample-#        TIMESTAMPTZ '2024-01-01 00:00:00' +
sample-#           (abs(hashint8(-i)) % 200) * INTERVAL '1 hour',
sample-#        substr(md5(i::text), 1, 2)
sample-# FROM generate_series(1, 1000000) AS i;
INSERT 0 1000000
sample=#
sample=# -- get statistics and set hint bits
sample=# VACUUM (ANALYZE) sortme;
VACUUM
```

### 通常のキーセットページネーション

最初のクエリは次のようになります。

```sql
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# ORDER BY val1, val2, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
    1 | 2024-01-01 00:00:00+09 | 97   |  23994
    1 | 2024-01-01 00:00:00+09 | fa   |  31346
・・・
    1 | 2024-01-01 01:00:00+09 | 45   | 845782
    1 | 2024-01-01 01:00:00+09 | e3   | 920198
(50 行)
```

```sql
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# WHERE (val1, val2, id) > (1, '2024-01-01 01:00:00+01', 920198)
sample-# ORDER BY val1, val2, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
    1 | 2024-01-01 09:00:00+09 | f3   | 922918
    1 | 2024-01-01 09:00:00+09 | 97   | 948540
・・・
    1 | 2024-01-01 11:00:00+09 | e3   | 636355
    1 | 2024-01-01 11:00:00+09 | d8   | 663580
(50 行)
```

### 降順および混合順でのキーセットページネーションの問題

```sql
sample=# -- first page
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# ORDER BY val3 DESC, id DESC
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
  153 | 2024-01-05 06:00:00+09 | ff   | 999984
   27 | 2024-01-06 09:00:00+09 | ff   | 999923
・・・
   80 | 2024-01-08 07:00:00+09 | ff   | 986836
   28 | 2024-01-05 00:00:00+09 | ff   | 986821
(50 行)
```

### 負の値を使用したキーセットのページネーション

```sql
sample=# -- first page
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# ORDER BY val3, -val1, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
  200 | 2024-01-07 03:00:00+09 | 00   |  82014
  200 | 2024-01-07 03:00:00+09 | 00   |  90573
・・・
  198 | 2024-01-04 22:00:00+09 | 00   | 204494
  198 | 2024-01-05 01:00:00+09 | 00   | 219956
(50 行)


sample=# -- next page
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# WHERE (val3, -val1, id) > ('00', -198, 219956)
sample-# ORDER BY val3, -val1, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
  198 | 2024-01-03 04:00:00+09 | 00   | 220422
  198 | 2024-01-04 14:00:00+09 | 00   | 245614
・・・
  196 | 2024-01-01 12:00:00+09 | 00   | 706727
  196 | 2024-01-05 20:00:00+09 | 00   | 725097
(50 行)
```

このクエリをサポートするために必要なインデックスは

```sql

```

### タイムスタンプの「負の値」

```sql
sample=# -- first page
sample=# SELECT val1, val2, val3, - EXTRACT (epoch FROM val2), id
sample-# FROM sortme
sample-# ORDER BY val3, - EXTRACT (epoch FROM val2), id
sample-# LIMIT 50;
 val1 |          val2          | val3 |      ?column?      |   id
------+------------------------+------+--------------------+--------
  126 | 2024-01-09 07:00:00+09 | 00   | -1704751200.000000 |  84414
  143 | 2024-01-09 07:00:00+09 | 00   | -1704751200.000000 |  89254
・・・
  170 | 2024-01-09 05:00:00+09 | 00   | -1704744000.000000 | 181726
   55 | 2024-01-09 05:00:00+09 | 00   | -1704744000.000000 | 204901
(50 行)


sample=# -- next page
sample=# SELECT val1, val2, val3, - EXTRACT (epoch FROM val2), id
sample-# FROM sortme
sample-# WHERE (val3, - EXTRACT (epoch FROM val2), id) >
sample-#       ('00', -1704772800.000000, 204901)
sample-# ORDER BY val3, - EXTRACT (epoch FROM val2), id
sample-# LIMIT 50;
 val1 |          val2          | val3 |      ?column?      |   id
------+------------------------+------+--------------------+--------
  126 | 2024-01-09 07:00:00+09 | 00   | -1704751200.000000 |  84414
  143 | 2024-01-09 07:00:00+09 | 00   | -1704751200.000000 |  89254
・・・
  170 | 2024-01-09 05:00:00+09 | 00   | -1704744000.000000 | 181726
   55 | 2024-01-09 05:00:00+09 | 00   | -1704744000.000000 | 204901
(50 行)
```

必要なインデックスを作ろうとすると失敗します

```Sql
sample=# CREATE INDEX ON sortme (val3, (- EXTRACT (epoch FROM val2)), id);
ERROR:  式インデックスの関数はIMMUTABLEマークが必要です
```

Unix エポックの抽出は不変なので、その目的のために関数を定義することで、この問題を安全に回避できます

```sql
sample=# CREATE FUNCTION get_epoch(timestamp with time zone) RETURNS numeric
sample-#    IMMUTABLE
sample-#    RETURN EXTRACT (epoch FROM $1);
CREATE FUNCTION
sample=#
sample=# CREATE INDEX ON sortme (val3, (- get_epoch(val2)), id);
CREATE INDEX
```

### クエリを分割してキーセットのページネーションを行う

```sql
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# WHERE val2 > '2024-01-01 00:00:00+01'
sample-#    OR val2 = '2024-01-01 00:00:00+01'
sample-#       AND val3 < 'fc'
sample-#    OR val2 = '2024-01-01 00:00:00+01'
sample-#       AND val3 = 'fc'
sample-#       AND id > 173511
sample-# ORDER BY val2, val3 DESC, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
  180 | 2024-01-01 08:00:00+09 | fc   | 188547
   77 | 2024-01-01 08:00:00+09 | fc   | 210011
  102 | 2024-01-01 08:00:00+09 | fc   | 229211
・・・
  100 | 2024-01-01 08:00:00+09 | fa   | 200583
   70 | 2024-01-01 08:00:00+09 | fa   | 441388
(50 行)
```

`OR`句を使うと遅いので`UNION ALL`に置き換えます  
3 つの副問い合わせが、それぞれインデックススキャンするため早いです

```sql
sample=#   (SELECT val1, val2, val3, id
sample(#    FROM sortme
sample(#    WHERE val2 > '2024-01-01 00:00:00+01'
sample(#    ORDER BY val2, val3 DESC, id
sample(#    LIMIT 50)
sample-# UNION ALL
sample-#   (SELECT val1, val2, val3, id
sample(#    FROM sortme
sample(#    WHERE val2 = '2024-01-01 00:00:00+01'
sample(#      AND val3 < 'fc'
sample(#    ORDER BY val2, val3 DESC, id
sample(#    LIMIT 50)
sample-# UNION ALL
sample-#   (SELECT val1, val2, val3, id
sample(#    FROM sortme
sample(#    WHERE val2 = '2024-01-01 00:00:00+01'
sample(#      AND val3 = 'fc'
sample(#      AND id > 173511
sample(#    ORDER BY val2, val3 DESC, id
sample(#    LIMIT 50)
sample-# ORDER BY val2, val3 DESC, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
  180 | 2024-01-01 08:00:00+09 | fc   | 188547
   77 | 2024-01-01 08:00:00+09 | fc   | 210011
・・・
  100 | 2024-01-01 08:00:00+09 | fa   | 200583
   70 | 2024-01-01 08:00:00+09 | fa   | 441388
(50 行)
```

### カスタムデータ型の定義によるキーセットページネーション

```sql
sample=# -- the real type definition will come later
sample=# CREATE TYPE invtext;
CREATE TYPE
sample=#
sample=# CREATE FUNCTION invtextin(cstring) RETURNS invtext
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
sample-# AS 'textin';
NOTICE:  戻り値型invtextは単なるシェル型です
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtextout(invtext) RETURNS cstring
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE
sample-# AS 'textout';
NOTICE:  引数型invtextは単なるシェルです
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtextrecv(internal) RETURNS invtext
sample-#    LANGUAGE internal STABLE STRICT PARALLEL SAFE
sample-# AS 'textrecv';
NOTICE:  戻り値型invtextは単なるシェル型です
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtextsend(invtext) RETURNS bytea
sample-#    LANGUAGE internal STABLE STRICT PARALLEL SAFE
sample-# AS 'textsend';
NOTICE:  引数型invtextは単なるシェルです
CREATE FUNCTION
sample=#
sample=# -- now we can create the type for real
sample=# CREATE TYPE invtext (
sample(#    INPUT          = invtextin,
sample(#    OUTPUT         = invtextout,
sample(#    RECEIVE        = invtextrecv,
sample(#    SEND           = invtextsend,
sample(#    INTERNALLENGTH = VARIABLE,
sample(#    STORAGE        = extended,
sample(#    CATEGORY       = 'S',
sample(#    PREFERRED      = false,
sample(#    COLLATABLE     = true
sample(# );
CREATE TYPE
sample=#
sample=# CREATE CAST (text AS invtext) WITHOUT FUNCTION;
CREATE CAST
sample=# CREATE CAST (invtext AS text) WITHOUT FUNCTION;
CREATE CAST
sample=# CREATE CAST (character varying AS invtext) WITHOUT FUNCTION;
CREATE CAST
```

ここまでは invtext は text と全く同じです

### データ型の比較演算子の定義

```sql
sample=# CREATE FUNCTION invtexteq(invtext, invtext) RETURNS boolean
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE LEAKPROOF
sample-# AS 'texteq';
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtextne(invtext, invtext) RETURNS boolean
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE LEAKPROOF
sample-# AS 'textne';
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtext_lt(invtext, invtext) RETURNS boolean
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE LEAKPROOF
sample-# AS 'text_gt';
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtext_le(invtext, invtext) RETURNS boolean
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE LEAKPROOF
sample-# AS 'text_ge';
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtext_gt(invtext, invtext) RETURNS boolean
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE LEAKPROOF
sample-# AS 'text_lt';
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION invtext_ge(invtext, invtext) RETURNS boolean
sample-#    LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE LEAKPROOF
sample-# AS 'text_le';
CREATE FUNCTION
sample=#
sample=# CREATE OPERATOR = (
sample(#    LEFTARG    = invtext,
sample(#    RIGHTARG   = invtext,
sample(#    COMMUTATOR = =,
sample(#    NEGATOR    = <>,
sample(#    PROCEDURE  = invtexteq,
sample(#    RESTRICT   = eqsel,
sample(#    JOIN       = eqjoinsel,
sample(#    HASHES,
sample(#    MERGES
sample(# );
CREATE OPERATOR
sample=#
sample=# CREATE OPERATOR <> (
sample(#    LEFTARG    = invtext,
sample(#    RIGHTARG   = invtext,
sample(#    NEGATOR    = =,
sample(#    COMMUTATOR = <>,
sample(#    PROCEDURE  = invtextne,
sample(#    RESTRICT   = neqsel,
sample(#    JOIN       = neqjoinsel
sample(# );
CREATE OPERATOR
sample=#
sample=# CREATE OPERATOR < (
sample(#     LEFTARG    = invtext,
sample(#     RIGHTARG   = invtext,
sample(#     NEGATOR    = >=,
sample(#     COMMUTATOR = >,
sample(#     PROCEDURE  = invtext_lt,
sample(#     RESTRICT   = scalargtsel,
sample(#     JOIN       = scalargtjoinsel
sample(# );
CREATE OPERATOR
sample=#
sample=# CREATE OPERATOR <= (
sample(#     LEFTARG    = invtext,
sample(#     RIGHTARG   = invtext,
sample(#     NEGATOR    = >,
sample(#     COMMUTATOR = >=,
sample(#     PROCEDURE  = invtext_le,
sample(#     RESTRICT   = scalargtsel,
sample(#     JOIN       = scalargtjoinsel
sample(# );
CREATE OPERATOR
sample=#
sample=# CREATE OPERATOR >= (
sample(#     LEFTARG    = invtext,
sample(#     RIGHTARG   = invtext,
sample(#     NEGATOR    = <,
sample(#     COMMUTATOR = <=,
sample(#     PROCEDURE  = invtext_ge,
sample(#     RESTRICT   = scalarltsel,
sample(#     JOIN       = scalarltjoinsel
sample(# );
CREATE OPERATOR
sample=#
sample=# CREATE OPERATOR > (
sample(#     LEFTARG    = invtext,
sample(#     RIGHTARG   = invtext,
sample(#     NEGATOR    = <=,
sample(#     COMMUTATOR = <,
sample(#     PROCEDURE  = invtext_gt,
sample(#     RESTRICT   = scalarltsel,
sample(#     JOIN       = scalarltjoinsel
sample(# );
CREATE OPERATOR
```

### データ型の B ツリー演算子クラスの定義

```sql
sample=# CREATE OPERATOR CLASS invtext_ops
sample-# DEFAULT FOR TYPE invtext USING btree AS
sample-#    OPERATOR 1 <(invtext, invtext),
sample-#    OPERATOR 2 <=(invtext, invtext),
sample-#    OPERATOR 3 =(invtext, invtext),
sample-#    OPERATOR 4 >=(invtext, invtext),
sample-#    OPERATOR 5 >(invtext, invtext),
sample-#    FUNCTION 1 btinvtextcmp(invtext, invtext);
CREATE OPERATOR CLASS
```

### キーセットのページネーションにカスタムデータ型を使用する

```sql
sample=# -- first page
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# ORDER BY val2, val3::invtext, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
  106 | 2024-01-01 00:00:00+09 | ff   | 100199
   48 | 2024-01-01 00:00:00+09 | ff   | 186779
・・・
   67 | 2024-01-01 00:00:00+09 | fc   | 117040
   99 | 2024-01-01 00:00:00+09 | fc   | 173511
(50 行)
```

```Sql
sample=# -- second page
sample=# SELECT val1, val2, val3, id
sample-# FROM sortme
sample-# WHERE (val2, val3::invtext, id) >
sample-#       ('2024-01-01 00:00:00+01', 'fc', 173511)
sample-# ORDER BY val2, val3::invtext, id
sample-# LIMIT 50;
 val1 |          val2          | val3 |   id
------+------------------------+------+--------
  180 | 2024-01-01 08:00:00+09 | fc   | 188547
   77 | 2024-01-01 08:00:00+09 | fc   | 210011
・・・
  100 | 2024-01-01 08:00:00+09 | fa   | 200583
   70 | 2024-01-01 08:00:00+09 | fa   | 441388
(50 行)
```

これらのクエリをサポートするインデックス

```sql
sample=# CREATE INDEX ON sortme (val2, (val3::invtext), id);
CREATE INDEX
```

### 結論

一部の列が昇順で並べ替えられ、他の列が降順で並べ替えられている場合に、キーセット ページネーションを効率的に機能させるための 3 つのトリックを見てきました。

- 降順の列の負の数で並べ替えて昇順にする
- インデックスを使用できるスカラー比較を持つサブクエリの結合を使用する
- 逆のソート順を持つカスタムデータ型を定義し、降順の列にそれを使用して昇順にします。
