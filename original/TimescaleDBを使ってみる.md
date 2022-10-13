# TimescaleDB を使ってみる

TimrscaleDB の概要をハンズオンチュートリアルを行うことで理解する。  
PG_EXTENTION で簡単にインストールできるため、ローカル環境で実験します。  
2022 年 10 月 8 日時点で、クラウドサービスとして提供しない限り無料で使用できます。

# 感想

時間の経過とともに蓄積されるデータにより巨大化するテーブルを効率よく扱う PostgreSQL の拡張機能。  
ログを扱う DB システムであれば、使っておいて損はない。

# TimescaleDB

TimescaleDB は PostgreSQL を時系列データ用に拡張し、最新のデータ集約型アプリケーションに必要な高性能、スケーラビリティ、および分析機能を PostgreSQL に提供します。

---

[代表的な機能]

- ハイパーテーブル・・・時系列データを効率的に扱えるテーブル
- 連続集計・・・定期的に更新する集計テーブル(マテビュー)
- 時系列テーブル圧縮・・・過去データの圧縮が可能。ルール定義
- データ保持ポリシー・・・ポリシーに応じてデータの保持期限を定義

---

### [インストール手順]

[公式ページ](https://docs.timescale.com/install/latest/)参考。

### [パフォーマンス計測]

[公式チュートリアル](https://docs.timescale.com/timescaledb/latest/tutorials/nyc-taxi-cab/)にある SQL クエリが、timescaleDB を使うことで、どの程度変わるか雑に見ていく。

- 1.PowerShell から psql クライアントの起動

```
psql -U postgres
ユーザー postgres のパスワード:
psql (14.5)
"help"でヘルプを表示します。
```

- 2.tsdb という名前でデータベースを作成し、timescaledb を有効化します。

```sql
postgres=# CREATE DATABASE tsdb;
CREATE DATABASE
postgres=# \c tsdb
データベース"tsdb"にユーザー"postgres"として接続しました。
tsdb=# CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
WARNING:
WELCOME TO
 _____ _                               _     ____________
|_   _(_)                             | |    |  _  \ ___ \
  | |  _ _ __ ___   ___  ___  ___ __ _| | ___| | | | |_/ /
  | | | |  _ ` _ \ / _ \/ __|/ __/ _` | |/ _ \ | | | ___ \
  | | | | | | | | |  __/\__ \ (_| (_| | |  __/ |/ /| |_/ /
  |_| |_|_| |_| |_|\___||___/\___\__,_|_|\___|___/ \____/
               Running version 2.8.1
For more information on TimescaleDB, please visit the following links:

CREATE EXTENSION
```

- 3.データを、チュートリアルページからダウンロードします。  
  ※ファイルサイズは 1.5GB 程度あります。

* 4.テーブル等を作成します。

```sql
tsdb=# CREATE TABLE "rides"(
tsdb(#     vendor_id TEXT,
tsdb(#     pickup_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
tsdb(#     dropoff_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
tsdb(#     passenger_count NUMERIC,
tsdb(#     trip_distance NUMERIC,
tsdb(#     pickup_longitude  NUMERIC,
tsdb(#     pickup_latitude   NUMERIC,
tsdb(#     rate_code         INTEGER,
tsdb(#     dropoff_longitude NUMERIC,
tsdb(#     dropoff_latitude  NUMERIC,
tsdb(#     payment_type INTEGER,
tsdb(#     fare_amount NUMERIC,
tsdb(#     extra NUMERIC,
tsdb(#     mta_tax NUMERIC,
tsdb(#     tip_amount NUMERIC,
tsdb(#     tolls_amount NUMERIC,
tsdb(#     improvement_surcharge NUMERIC,
tsdb(#     total_amount NUMERIC
tsdb(# );
CREATE TABLE
tsdb=# SELECT create_hypertable('rides', 'pickup_datetime', 'payment_type', 2, create_default_indexes=>FALSE);
 create_hypertable
--------------------
 (1,public,rides,t)
(1 行)


tsdb=# CREATE INDEX ON rides (vendor_id, pickup_datetime DESC);
CREATE INDEX
tsdb=# CREATE INDEX ON rides (rate_code, pickup_datetime DESC);
CREATE INDEX
tsdb=# CREATE INDEX ON rides (passenger_count, pickup_datetime DESC);
CREATE INDEX
tsdb=# CREATE TABLE IF NOT EXISTS "payment_types"(
tsdb(#     payment_type INTEGER,
tsdb(#     description TEXT
tsdb(# );
```

```sql
CREATE TABLE
tsdb=# INSERT INTO payment_types(payment_type, description) VALUES
tsdb-# (1, 'credit card'),
tsdb-# (2, 'cash'),
tsdb-# (3, 'no charge'),
tsdb-# (4, 'dispute'),
tsdb-# (5, 'unknown'),
tsdb-# (6, 'voided trip');
INSERT 0 6
tsdb=#
```

```sql
tsdb=# CREATE TABLE IF NOT EXISTS "rates"(
tsdb(#     rate_code   INTEGER,
tsdb(#     description TEXT
tsdb(# );
CREATE TABLE
tsdb=# INSERT INTO rates(rate_code, description) VALUES
tsdb-# (1, 'standard rate'),
tsdb-# (2, 'JFK'),
tsdb-# (3, 'Newark'),
tsdb-# (4, 'Nassau or Westchester'),
tsdb-# (5, 'negotiated fare'),
tsdb-# (6, 'group ride');
```

- 5.ダウンロードしたデータを取り込みます。貧弱な PC なので 10 分程度かかりました。

```sql
tsdb=# \COPY rides FROM C:\Users\user\Downloads\nyc_data_rides.csv CSV;
COPY 10906860
```

- 6.ntsdb という名前でデータベースを作成します。timescaledb は使いません。

```sql
postgres=# CREATE DATABASE ntsdb;
postgres=# \c ntsdb
```

- 7.テーブル等を作成します。

```sql
ntsdb=# CREATE TABLE "rides"(
ntsdb(#     vendor_id TEXT,
ntsdb(#     pickup_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
ntsdb(#     dropoff_datetime TIMESTAMP WITHOUT TIME ZONE NOT NULL,
ntsdb(#     passenger_count NUMERIC,
ntsdb(#     trip_distance NUMERIC,
ntsdb(#     pickup_longitude  NUMERIC,
ntsdb(#     pickup_latitude   NUMERIC,
ntsdb(#     rate_code         INTEGER,
ntsdb(#     dropoff_longitude NUMERIC,
ntsdb(#     dropoff_latitude  NUMERIC,
ntsdb(#     payment_type INTEGER,
ntsdb(#     fare_amount NUMERIC,
ntsdb(#     extra NUMERIC,
ntsdb(#     mta_tax NUMERIC,
ntsdb(#     tip_amount NUMERIC,
ntsdb(#     tolls_amount NUMERIC,
ntsdb(#     improvement_surcharge NUMERIC,
ntsdb(#     total_amount NUMERIC
ntsdb(# );
CREATE TABLE
ntsdb=# CREATE INDEX ON rides (vendor_id, pickup_datetime DESC);
CREATE INDEX
ntsdb=# CREATE INDEX ON rides (rate_code, pickup_datetime DESC);
CREATE INDEX
ntsdb=# CREATE INDEX ON rides (passenger_count, pickup_datetime DESC);
CREATE INDEX
```

```sql
ntsdb=# CREATE TABLE IF NOT EXISTS "payment_types"(
ntsdb(#     payment_type INTEGER,
ntsdb(#     description TEXT
ntsdb(# );
CREATE TABLE
ntsdb=# INSERT INTO payment_types(payment_type, description) VALUES
ntsdb-# (1, 'credit card'),
ntsdb-# (2, 'cash'),
ntsdb-# (3, 'no charge'),
ntsdb-# (4, 'dispute'),
ntsdb-# (5, 'unknown'),
ntsdb-# (6, 'voided trip');
INSERT 0 6
```

```sql
ntsdb=# CREATE TABLE IF NOT EXISTS "rates"(
ntsdb(#     rate_code   INTEGER,
ntsdb(#     description TEXT
ntsdb(# );
CREATE TABLE
ntsdb=# INSERT INTO rates(rate_code, description) VALUES
ntsdb-# (1, 'standard rate'),
ntsdb-# (2, 'JFK'),
ntsdb-# (3, 'Newark'),
ntsdb-# (4, 'Nassau or Westchester'),
ntsdb-# (5, 'negotiated fare'),
ntsdb-# (6, 'group ride');
```

```sql
ntsdb=# \COPY rides FROM C:\Users\user\Downloads\nyc_data_rides.csv CSV;
COPY 10906860
```

- 8.測定結果  
  キャッシュが効くと困るので、測定する度にサーバーを再起動しています。

## ケース 1:毎日何回乗車しましたか。

```sql
EXPLAIN ANALYZE SELECT date_trunc('day', pickup_datetime) as day, COUNT(*) FROM rides GROUP BY day ORDER BY day;
```

### ■ 測定結果

| timescaleDB | Planning(ms) | Execution(ms) |
| ----------- | ------------ | ------------- |
| 有          | 62.711       | 5080.818      |
| 無          | 7.791        | 7932.694      |

## ケース 2:乗客の平均運賃はいくらですか?

```sql
EXPLAIN ANALYZE SELECT date_trunc('day', pickup_datetime)
AS day, avg(fare_amount)
FROM rides
WHERE passenger_count = 1
AND pickup_datetime < '2016-01-08'
GROUP BY day ORDER BY day;
```

### ■ 測定結果

| timescaleDB | Planning(ms) | Execution(ms) |
| ----------- | ------------ | ------------- |
| 有          | 29.664       | 1411.779      |
| 無          | 8.782        | 9834.168      |

## ケース 3:各料金タイプで何回乗車しましたか?

```sql
EXPLAIN ANALYZE SELECT rate_code, COUNT(vendor_id) AS num_trips
FROM rides
WHERE pickup_datetime < '2016-02-01'
GROUP BY rate_code
ORDER BY rate_code;
```

### ■ 測定結果

| timescaleDB | Planning(ms) | Execution(ms) |
| ----------- | ------------ | ------------- |
| 有          | 42.923       | 4797.226      |
| 無          | 7.086        | 5703.684      |

```sql
EXPLAIN ANALYZE SELECT rates.description, COUNT(vendor_id) AS num_trips,
  RANK () OVER (ORDER BY COUNT(vendor_id) DESC) AS trip_rank FROM rides
  JOIN rates ON rides.rate_code = rates.rate_code
  WHERE pickup_datetime < '2016-02-01'
  GROUP BY rates.description
  ORDER BY LOWER(rates.description);
```

### ■ 測定結果

| timescaleDB | Planning(ms) | Execution(ms) |
| ----------- | ------------ | ------------- |
| 有          | 56.834       | 11018.092     |
| 無          | 8.515        | 21127.457     |

## ケース 4:JFK と EWR への乗り物の分析

```sql
EXPLAIN ANALYZE SELECT rates.description, COUNT(vendor_id) AS num_trips,
   AVG(dropoff_datetime - pickup_datetime) AS avg_trip_duration, AVG(total_amount) AS avg_total,
   AVG(tip_amount) AS avg_tip, MIN(trip_distance) AS min_distance, AVG (trip_distance) AS avg_distance, MAX(trip_distance) AS max_distance,
   AVG(passenger_count) AS avg_passengers
 FROM rides
 JOIN rates ON rides.rate_code = rates.rate_code
 WHERE rides.rate_code IN (2,3) AND pickup_datetime < '2016-02-01'
 GROUP BY rates.description
 ORDER BY rates.description;
```

### ■ 測定結果

| timescaleDB | Planning(ms) | Execution(ms) |
| ----------- | ------------ | ------------- |
| 有          | 60.040       | 12247.982     |
| 無          | 11.322       | 5592.688      |

※timescale ない方が早い。
timescale 有は、Parallel Index Scan が 10 並列で動いているのが影響してそうです。

## ケース 5:2016 年の最初の日に 5 分ごとに何回の乗車が行われましたか?

```sql
EXPLAIN ANALYZE SELECT
  EXTRACT(hour from pickup_datetime) as hours,
  trunc(EXTRACT(minute from pickup_datetime) / 5)*5 AS five_mins,
  COUNT(*)
FROM rides
WHERE pickup_datetime < '2016-01-02 00:00'
GROUP BY hours, five_mins;
```

timescaleDB で用意されているカスタム関数使用版

```sql
EXPLAIN ANALYZE SELECT time_bucket('5 minute', pickup_datetime) AS five_min, count(*)
FROM rides
WHERE pickup_datetime < '2016-01-02 00:00'
GROUP BY five_min
ORDER BY five_min;
```

### ■ 測定結果

| timescaleDB      | Planning(ms) | Execution(ms) |
| ---------------- | ------------ | ------------- |
| 有               | 32.693       | 765.155       |
| 有(カスタム関数) | 24.459       | 223.563       |
| 無               | 9.076        | 3535.393      |

正直、PostgreSQL の知識が大分飛んでいるのですが、パーティションを切って物理的に格納スペースを分けて、パラレルインデックススキャンをしているから早い感じですかね。  
テーブル生成時に実行した下記 SQL ですが、rides テーブルを pickup_datetime カラムを見て、よしなにパーティションを切るといった感じのようです。  
ただ、ハイパーテーブルが timescaleDB の肝となっているとのことなので、他にも様々な工夫がなされているとは思います。

```sql
SELECT create_hypertable('rides', 'pickup_datetime', 'payment_type', 2, create_default_indexes=>FALSE);
```

plpgsql じゃなくて、C で作られた関数なので中身は確認していないです。  
もし、そうであれば、パーティションに使われる列を条件に検索している場合は、パフォーマンスが良さそうです。
