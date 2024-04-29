# pg_partman を使ってみる

pg_partman は postgresql のパーティションテーブルセットを管理する拡張機能です  
テーブルパーティションの作成とメンテナンスを自動化できます
現在、pg_partman は RANGE タイプのパーティショニング (時間と ID の両方) のみをサポートしています

https://github.com/pgpartman/pg_partman

HowToGuide を実施していきます

インストール

```
sudo apt-get -y install postgresql-14-partman
```

postgresql.conf の編集

```
shared_preload_libraries = 'pg_partman_bgw'     # (change requires restart)
```

サービス再起動

```
root@masami-L /e/p/1/main# systemctl restart postgresql
```

データベース準備

```
postgres@masami-L ~> createdb -U postgres sample
postgres@masami-L ~> psql -U postgres -d sample
psql (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
Type "help" for help.
```

pg_partman の導入と使用スキーマの作成

```sql
sample=# CREATE SCHEMA partman;
CREATE EXTENSION pg_partman SCHEMA partman;
CREATE SCHEMA
CREATE EXTENSION
```

pg_partman 用のロール作成

```sql
sample=# CREATE ROLE partman_user WITH LOGIN;
GRANT ALL ON SCHEMA partman TO partman_user;
GRANT ALL ON ALL TABLES IN SCHEMA partman TO partman_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA partman TO partman_user;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA partman TO partman_user;
GRANT ALL ON SCHEMA partman TO partman_user;
GRANT TEMPORARY ON DATABASE sample to partman_user; -- allow creation of temp tables to move data out of default
CREATE ROLE
GRANT
GRANT
GRANT
GRANT
GRANT
GRANT
```

## シンプルな時間ベース: 1 日あたり 1 つのパーティション

```sql
sample=# CREATE SCHEMA IF NOT EXISTS partman_test;

CREATE TABLE partman_test.time_taptest_table
    (col1 int,
    col2 text default 'stuff',
    col3 timestamptz NOT NULL DEFAULT now())
PARTITION BY RANGE (col3);

CREATE INDEX ON partman_test.time_taptest_table (col3);
CREATE SCHEMA
CREATE TABLE
CREATE INDEX

sample=# \d+ partman_test.time_taptest_table
                                      Partitioned table "partman_test.time_taptest_table"
 Column |           Type           | Collation | Nullable |    Default    | Storage  | Compression | Stats target | Description
--------+--------------------------+-----------+----------+---------------+----------+-------------+--------------+-------------
 col1   | integer                  |           |          |               | plain    |             |              |
 col2   | text                     |           |          | 'stuff'::text | extended |             |              |
 col3   | timestamp with time zone |           | not null | now()         | plain    |             |              |
Partition key: RANGE (col3)
Indexes:
    "time_taptest_table_col3_idx" btree (col3)
Number of partitions: 0
```

パーティションキーに含めない限り、ユニークキーは親テーブルに作成できません

最初にテンプレート テーブルを手動で作成し、実行時に作成される最初の子テーブルに主キーが設定されるようにします。

```Sql
sample=# CREATE TABLE partman_test.time_taptest_table_template (LIKE partman_test.time_taptest_table);

ALTER TABLE partman_test.time_taptest_table_template ADD PRIMARY KEY (col1);
CREATE TABLE
ALTER TABLE

sample=#  \d partman_test.time_taptest_table_template
          Table "partman_test.time_taptest_table_template"
 Column |           Type           | Collation | Nullable | Default
--------+--------------------------+-----------+----------+---------
 col1   | integer                  |           | not null |
 col2   | text                     |           |          |
 col3   | timestamp with time zone |           | not null |
Indexes:
    "time_taptest_table_template_pkey" PRIMARY KEY, btree (col1)
```

```sql
sample=# SELECT partman.create_parent(
    p_parent_table => 'partman_test.time_taptest_table'
    , p_control => 'col3'
    , p_type => 'native'
    , p_interval => '1 day'
    , p_template_table => 'partman_test.time_taptest_table_template'
);
 create_parent
---------------
 t
(1 row)

                                      Partitioned table "partman_test.time_taptest_table"
 Column |           Type           | Collation | Nullable |    Default    | Storage  | Compression | Stats target | Description
--------+--------------------------+-----------+----------+---------------+----------+-------------+--------------+-------------
 col1   | integer                  |           |          |               | plain    |             |              |
 col2   | text                     |           |          | 'stuff'::text | extended |             |              |
                                      Partitioned table "partman_test.time_taptest_table"
 Column |           Type           | Collation | Nullable |    Default    | Storage  | Compression | Stats target | Description
--------+--------------------------+-----------+----------+---------------+----------+-------------+--------------+-------------
 col1   | integer                  |           |          |               | plain    |             |              |
 col2   | text                     |           |          | 'stuff'::text | extended |             |              |
 col3   | timestamp with time zone |           | not null | now()         | plain    |             |              |
Partition key: RANGE (col3)
Indexes:
    "time_taptest_table_col3_idx" btree (col3)
Partitions: partman_test.time_taptest_table_p2024_02_13 FOR VALUES FROM ('2024-02-13 00:00:00+09') TO ('2024-02-14 00:00:00+09'),
            partman_test.time_taptest_table_p2024_02_14 FOR VALUES FROM ('2024-02-14 00:00:00+09') TO ('2024-02-15 00:00:00+09'),
            partman_test.time_taptest_table_p2024_02_15 FOR VALUES FROM ('2024-02-15 00:00:00+09') TO ('2024-02-16 00:00:00+09'),
            partman_test.time_taptest_table_p2024_02_16 FOR VALUES FROM ('2024-02-16 00:00:00+09') TO ('2024-02-17 00:00:00+09'),
            partman_test.time_taptest_table_p2024_02_17 FOR VALUES FROM ('2024-02-17 00:00:00+09') TO ('2024-02-18 00:00:00+09'),
            partman_test.time_taptest_table_p2024_02_18 FOR VALUES FROM ('2024-02-18 00:00:00+09') TO ('2024-02-19 00:00:00+09'),
:

sample=# \d+ partman_test.time_taptest_table_p2024_02_14
                                      Table "partman_test.time_taptest_table_p2024_02_14"
 Column |           Type           | Collation | Nullable |    Default    | Storage  | Compression | Stats target | Description
--------+--------------------------+-----------+----------+---------------+----------+-------------+--------------+-------------
 col1   | integer                  |           | not null |               | plain    |             |              |
 col2   | text                     |           |          | 'stuff'::text | extended |             |              |
 col3   | timestamp with time zone |           | not null | now()         | plain    |             |              |
Partition of: partman_test.time_taptest_table FOR VALUES FROM ('2024-02-14 00:00:00+09') TO ('2024-02-15 00:00:00+09')
Partition constraint: ((col3 IS NOT NULL) AND (col3 >= '2024-02-14 00:00:00+09'::timestamp with time zone) AND (col3 < '2024-02-15 00:00:00+09'::timestamp with time zone))
Indexes:
    "time_taptest_table_p2024_02_14_pkey" PRIMARY KEY, btree (col1)
    "time_taptest_table_p2024_02_14_col3_idx" btree (col3)
Access method: heap
```

### シンプルなシリアル ID: 10 ID 値ごとに 1 つのパーティション

```sql
sample=# CREATE TABLE partman_test.id_taptest_table (
    col1 bigint not null
    , col2 text
    , col3 timestamptz DEFAULT now() not null
    , col4 text)
PARTITION BY RANGE (col1);

CREATE INDEX ON partman_test.id_taptest_table (col1);
CREATE TABLE
CREATE INDEX
sample=# \d+ partman_test.id_taptest_table
                                    Partitioned table "partman_test.id_taptest_table"
 Column |           Type           | Collation | Nullable | Default | Storage  | Compression | Stats target | Description
--------+--------------------------+-----------+----------+---------+----------+-------------+--------------+-------------
 col1   | bigint                   |           | not null |         | plain    |             |              |
 col2   | text                     |           |          |         | extended |             |              |
 col3   | timestamp with time zone |           | not null | now()   | plain    |             |              |
 col4   | text                     |           |          |         | extended |             |              |
Partition key: RANGE (col1)
Indexes:
    "id_taptest_table_col1_idx" btree (col1)
Number of partitions: 0
```

```Sql
sample=# SELECT partman.create_parent(
    p_parent_table := 'partman_test.id_taptest_table'
    , p_control := 'col1', p_type => 'native'
    , p_interval := '10'
);
 create_parent
---------------
 t
(1 row)
sample=# \d+ partman_test.id_taptest_table
                                    Partitioned table "partman_test.id_taptest_table"
 Column |           Type           | Collation | Nullable | Default | Storage  | Compression | Stats target | Description
--------+--------------------------+-----------+----------+---------+----------+-------------+--------------+-------------
 col1   | bigint                   |           | not null |         | plain    |             |              |
 col2   | text                     |           |          |         | extended |             |              |
 col3   | timestamp with time zone |           | not null | now()   | plain    |             |              |
 col4   | text                     |           |          |         | extended |             |              |
Partition key: RANGE (col1)
Indexes:
    "id_taptest_table_col1_idx" btree (col1)
Partitions: partman_test.id_taptest_table_p0 FOR VALUES FROM ('0') TO ('10'),
            partman_test.id_taptest_table_p10 FOR VALUES FROM ('10') TO ('20'),
            partman_test.id_taptest_table_p20 FOR VALUES FROM ('20') TO ('30'),
            partman_test.id_taptest_table_p30 FOR VALUES FROM ('30') TO ('40'),
            partman_test.id_taptest_table_p40 FOR VALUES FROM ('40') TO ('50'),
            partman_test.id_taptest_table_default DEFAULT
```

テンプレート テーブルの名前は、その親テーブルの pg_partman 設定を調べることで確認できます。

```sql
sample=# SELECT template_table
FROM partman.part_config
WHERE parent_table = 'partman_test.id_taptest_table';
                 template_table
------------------------------------------------
 partman.template_partman_test_id_taptest_table
(1 row)
```

```sql
sample=# ALTER TABLE partman.template_partman_test_id_taptest_table ADD PRIMARY KEY (col2);
ALTER TABLE
sample=# INSERT INTO partman_test.id_taptest_table (col1, col2) VALUES (generate_series(1,20), generate_series(1,20)::text||'stuff'::text);

CALL partman.run_maintenance_proc();

\d+ partman_test.id_taptest_table
INSERT 0 20
CALL

                                    Partitioned table "partman_test.id_taptest_table"
 Column |           Type           | Collation | Nullable | Default | Storage  | Compression | Stats target | Description
--------+--------------------------+-----------+----------+---------+----------+-------------+--------------+-------------
 col1   | bigint                   |           | not null |         | plain    |             |              |
 col2   | text                     |           |          |         | extended |             |              |
 col3   | timestamp with time zone |           | not null | now()   | plain    |             |              |
 col4   | text                     |           |          |         | extended |             |              |
Partition key: RANGE (col1)
Indexes:
    "id_taptest_table_col1_idx" btree (col1)
Partitions: partman_test.id_taptest_table_p0 FOR VALUES FROM ('0') TO ('10'),
            partman_test.id_taptest_table_p10 FOR VALUES FROM ('10') TO ('20'),
            partman_test.id_taptest_table_p20 FOR VALUES FROM ('20') TO ('30'),
            partman_test.id_taptest_table_p30 FOR VALUES FROM ('30') TO ('40'),
            partman_test.id_taptest_table_p40 FOR VALUES FROM ('40') TO ('50'),
```

新しい子テーブル (p50 と p60) のみがその主キーを持ち、元のテーブル (p40 以前) には持たないことがわかります。

```sql
sample=# \d partman_test.id_taptest_table_p40
             Table "partman_test.id_taptest_table_p40"
 Column |           Type           | Collation | Nullable | Default
--------+--------------------------+-----------+----------+---------
 col1   | bigint                   |           | not null |
 col2   | text                     |           |          |
 col3   | timestamp with time zone |           | not null | now()
 col4   | text                     |           |          |
Partition of: partman_test.id_taptest_table FOR VALUES FROM ('40') TO ('50')
Indexes:
    "id_taptest_table_p40_col1_idx" btree (col1)

sample=# \d partman_test.id_taptest_table_p50
             Table "partman_test.id_taptest_table_p50"
 Column |           Type           | Collation | Nullable | Default
--------+--------------------------+-----------+----------+---------
 col1   | bigint                   |           | not null |
 col2   | text                     |           | not null |
 col3   | timestamp with time zone |           | not null | now()
 col4   | text                     |           |          |
Partition of: partman_test.id_taptest_table FOR VALUES FROM ('50') TO ('60')
Indexes:
    "id_taptest_table_p50_pkey" PRIMARY KEY, btree (col2)
    "id_taptest_table_p50_col1_idx" btree (col1)

sample=# \d partman_test.id_taptest_table_p60
             Table "partman_test.id_taptest_table_p60"
 Column |           Type           | Collation | Nullable | Default
--------+--------------------------+-----------+----------+---------
 col1   | bigint                   |           | not null |
 col2   | text                     |           | not null |
 col3   | timestamp with time zone |           | not null | now()
 col4   | text                     |           |          |
Partition of: partman_test.id_taptest_table FOR VALUES FROM ('60') TO ('70')
Indexes:
    "id_taptest_table_p60_pkey" PRIMARY KEY, btree (col2)
    "id_taptest_table_p60_col1_idx" btree (col1)
```

手動で追加します

```Sql
sample=# ALTER TABLE partman_test.id_taptest_table_p0 ADD PRIMARY KEY (col2);
ALTER TABLE partman_test.id_taptest_table_p10 ADD PRIMARY KEY (col2);
ALTER TABLE partman_test.id_taptest_table_p20 ADD PRIMARY KEY (col2);
ALTER TABLE partman_test.id_taptest_table_p30 ADD PRIMARY KEY (col2);
ALTER TABLE partman_test.id_taptest_table_p40 ADD PRIMARY KEY (col2);
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
ALTER TABLE
```
