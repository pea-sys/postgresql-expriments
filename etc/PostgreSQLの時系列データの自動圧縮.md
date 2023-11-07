# PostgreSQLの時系列データの自動圧縮
一般的に時系列データを素の記録状態で保持していると、テーブルサイズが増え続けていき、SELECTが次第に遅くなる問題があります。 
特に結合を行う場合のパフォーマンスに影響を及ぼす可能性が大きいです。 

時系列データを統計データの取得目的で保持している場合は、
任意の期間で区切り集計結果を保持することでデータ圧縮ができます。

こんな課題に対して、役に立ちそうな記事があったので実践します。  
以下をハンズオンでやります。  
https://www.alibabacloud.com/blog/postgresql-time-series-data-case-automatic-compression-over-time_594813


## Setup
```sql
C:\Users\masami>psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF-8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';"
CREATE DATABASE
```

## Tables
* tbl・・・素の時系列テーブル
* tbl_5min・・・最終日5分間隔の統計テーブル
* tbl_30min・・・最終週以前30分間隔の統計テーブル
![er](https://github.com/pea-sys/postgresql-expriments/assets/49807271/777e4f44-adcc-4362-86c8-2fb020063822)
```sql
sample=# create table tbl (
sample(#   id serial8 primary key,  -- primary key
sample(#   sid int,                 -- sensor ID
sample(#   hid int,                 -- indicator D
sample(#   val float8,              -- collected value
sample(#   ts timestamp             -- acquisition time
sample(# );
CREATE TABLE
sample=#
sample=# create index idx_tbl on tbl(ts);
CREATE INDEX
sample=# create table tbl_5min (
sample(#   id serial8 primary key,  -- primary key
sample(#   sid int,                 -- sensor ID
sample(#   hid int,                 -- indicator ID
sample(#   val float8,              -- inheritance, average, easy to do ring analysis
sample(#   ts timestamp,            -- inheritance, start time, easy to do ring analysis
sample(#   val_min float8,              -- minimum
sample(#   val_max float8,              -- maximum
sample(#   val_sum float8,              -- and
sample(#   val_count float8,            -- number of acquisitions
sample(#   ts_start timestamp,      -- interval start time
sample(#   ts_end timestamp         -- interval end time
sample(# );
CREATE TABLE
sample=#
sample=# alter table tbl_5min inherit tbl;
ALTER TABLE
sample=# create table tbl_30min (
sample(#   id serial8 primary key,  -- primary key
sample(#   sid int,                 -- sensor ID
sample(#   hid int,                 -- indicator ID
sample(#   val float8,              -- inheritance, average, easy to do ring analysis
sample(#   ts timestamp,            -- inheritance, start time, easy to do ring analysis
sample(#   val_min float8,              -- minimum
sample(#   val_max float8,              -- maximum
sample(#   val_sum float8,              -- and
sample(#   val_count float8,            -- number of acquisitions
sample(#   ts_start timestamp,      -- interval start time
sample(#   ts_end timestamp         -- interval end time
sample(#
sample(# );
CREATE TABLE
sample=#
sample=# alter table tbl_30min inherit tbl;
ALTER TABLE
```


### オリジナルデータ登録
```sql
sample=# insert into tbl (sid, hid, val, ts) select random()*1000, random()*5, random()*100,
sample-#   now()-interval '10 day' + (id * ((10*24*60*60/100000000.0)||' sec')::interval)
sample-# from generate_series(1,100000000) t(id); 
INSERT 0 100000000
```
* 通常圧縮はスケジューリング実行する(pg_cronとかpgAgentとか)
### 最終日データ圧縮
```sql
sample-# insert into tbl_5min
sample-#   (sid, hid, val, ts, val_min, val_max, val_sum, val_count, ts_start, ts_end)
sample-# select sid, hid, avg(val) as val, min(ts) as ts, min(val) as val_min, max(val) as val_max, sum(val) as val_sum, count(*) as val_count, min(ts) as ts_start, max(ts) as ts_end from
sample-# tmp1
sample-# group by sid, hid, substring(to_char(ts, 'yyyymmddhh24mi'), 1, 10) || lpad(((substring(to_char(ts, 'yyyymmddhh24mi'), 11, 2)::int / 5) * 5)::text, 2, '0');
INSERT 0 15428704
```

* レコードの合計は1億件から4000万件に圧縮
```
sample=# select count(cmin) from tbl;
  count
----------
 25261733
(1 行)
sample=# select count(cmin) from tbl_5min;
  count
----------
 15428704
(1 行)
sample=# select count(cmin) from tbl_30min;
 count
-------
     0
(1 行)
```
### 最終週以前のデータ圧縮
```sql
sample-# insert into tbl_30min
sample-#   (sid, hid, val_min, val_max, val_sum, val_count, ts_start, ts_end)
sample-# select sid, hid, min(val_min) as val_min, max(val_max) as val_max, sum(val_sum) as val_sum, sum(val_count) as val_count, min(ts_start) as ts_start, max(ts_end) as ts_end from
sample-# tmp1
sample-# group by sid, hid, substring(to_char(ts_start, 'yyyymmddhh24mi'), 1, 10) || lpad(((substring(to_char(ts_start, 'yyyymmddhh24mi'), 11, 2)::int / 30) * 30)::text, 2, '0');
INSERT 0 2605961
```

* レコードの合計は1400万件に圧縮
```sql
sample=# select count(cmin) from tbl;
  count
----------
 12438990
(1 行)
sample=# select count(cmin) from tbl_5min;
 count
-------
     0
(1 行)
sample=# select count(cmin) from tbl_30min;
  count
---------
 2605961
(1 行)
```

このように集計テーブルをもうけることで参照頻度の高い当日分データを保持するテーブルは1200万程度のデータサイズで維持可能であり、長期運用におけるパフォーマンス劣化を防止できる。