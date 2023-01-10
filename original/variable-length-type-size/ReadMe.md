# 可変長型のサイズ

可変長型のサイズは PostgreSQL のオフィシャルページでサイズが明示されていないので、測定しました。
対象型は以下です。
夫々実験に時間が掛かるので、地道にやっていきます。  
内部のデータの持ち方を知っていれば、式で一般化できそうですが、
無能なので脳筋測定しています。
留意するべきポイントとしては、可変長を使用することで
カラム視点で 1byte 節約できても実際、テーブル全体のサイズは変わらない可能性が高いということです。節約のために可変長型を使うかというと使わべきではないと考えています。

## [実験の流れ(共通)]

- 1.create table

```sql
create table numeric_table (
num1	 numeric(1	,1	),
num2	 numeric(2	,2	),
~~~~
num500   numeric(500,500)
);
```

- 2.insert

```sql
insert into numeric_table values (
0.1	,
0.11	,
~~~
0.11111.....
);
```

- 3.select

```sql
select
pg_column_size(num1)	 as 	numeric1	,
pg_column_size(num2)	 as 	numeric2	,
~~~
pg_column_size(num500)	 as 	numeric500
from numeric_table;
```

- select で得た結果をグラフ化する  
  実際には、行データの最大バイト数制限に引っかかるのでテーブルを分割して確認する必要があります。

## ■numeric(x,x), decimal(x)

最低 5 バイト確保される  
同じ型でも格納データによって、サイズは変わります。

![numeric(x,x)の使用バイト数](https://user-images.githubusercontent.com/49807271/211127674-825064b4-484c-4bec-9327-233ad6a14300.png)

## ■character(n), char(n)

空白部分は圧縮されます。
文字列長 1 が必ずしもサイズが小さくなるとは限らない。

![2](https://user-images.githubusercontent.com/49807271/211135506-f73e749a-f9d4-4cd9-a9fc-059f61d2d977.png)

## ■character varying(n), varchar(n)

こちらは空白埋めしないので完全に格納データに依存したバイト数になってます。

![varchar(x)の使用バイト数](https://user-images.githubusercontent.com/49807271/211138623-385e9312-1689-4313-9730-5edfb1076ec9.png)

## ■text

使用バイト数は varchar と全く同じです。

![textの使用バイト数](https://user-images.githubusercontent.com/49807271/211139110-2a37db7a-f6d2-4c30-82c0-028ea5f40fab.png)
