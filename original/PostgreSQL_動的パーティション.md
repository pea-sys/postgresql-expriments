# 動的パーティション

supabase の次の記事に紹介されている動的パーティションのトレースをします  
クエリやダウンタイムをブロックすることなくパーティションを作成し、データを移行する例です  
最初は単一テーブルとして設計したものに対して、パーティションが必要になったようなケース向けのソリューションです。

https://supabase.com/blog/postgres-dynamic-table-partitioning

pg_cron のインストール

```
sudo apt-get -y install postgresql-14-cron
```

protgresql.cnf で pg_cron をロードするように指定し、拡張機能をインストールする DB を指定します

```
shared_preload_libraries = 'pg_cron'
cron.database_name = 'sample'
```

postgresql の再起動

```
systemctl restart postgresql
```

データベース作成

```
postgres@masami-L ~> createdb -U postgres sample
postgres@masami-L ~> psql -U postgres -d sample
```

```sql
sample=# CREATE EXTENSION pg_cron;
CREATE EXTENSION
```

## パーティション導入前セットアップ

1 日に数百万件のチャット メッセージを保存する必要があるシミュレートされた「チャット アプリ」をセットアップします。

テーブル作成

```Sql
sample=# create table chats (
  id bigserial,
  created_at timestamptz not null default now(),
  primary key (id)
);

create table chat_messages (
  id bigserial,
  created_at timestamptz not null,
  chat_id bigint not null,
  chat_created_at timestamptz not null,
  message text not null,
  primary key (id),
  foreign key (chat_id) references chats (id)
);
CREATE TABLE
CREATE TABLE
```

データ作成

```Sql
sample=# INSERT INTO chats (created_at)
SELECT generate_series(
  '2022-01-01'::timestamptz,
  '2022-01-30 23:00:00'::timestamptz,
  interval '1 hour'
);

INSERT INTO chat_messages (
        created_at,
        chat_id,
        chat_created_at,
        message
)
SELECT
  mca,
  chats.id,
  chats.created_at,
  (SELECT ($$[0:2]={'hello','goodbye','I would like a sandwich please'}$$::text[])[trunc(random() * 3)::int])
FROM chats
CROSS JOIN LATERAL (
    SELECT generate_series(
        chats.created_at,
        chats.created_at + interval '1 day',
        interval '1 minute'
                ) AS mca
) b;

CREATE INDEX ON chats (created_at);
CREATE INDEX ON chat_messages (created_at);
INSERT 0 720
INSERT 0 1037520
CREATE INDEX
CREATE INDEX
```

## 動的パーティショニング

1 日毎にパーティションを作成します

親テーブルの作成

```sql
sample=# BEGIN;
CREATE SCHEMA app;

CREATE TABLE app.chats(
    id bigserial,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, created_at)  -- the partition column must be part of pk
    ) PARTITION BY RANGE (created_at);

CREATE INDEX "chats_created_at" ON app.chats (created_at);

CREATE TABLE app.chat_messages(
    id bigserial,
    created_at timestamptz NOT NULL,
    chat_id bigint NOT NULL,
    chat_created_at timestamptz NOT NULL,
    message text NOT NULL,
    PRIMARY KEY (id, created_at),
    FOREIGN KEY (chat_id, chat_created_at)   -- multicolumn fk to ensure
        REFERENCES app.chats(id, created_at)
    ) PARTITION BY RANGE (created_at);

CREATE INDEX "chat_messages_created_at" ON app.chat_messages (created_at);
--
-- need this index on the fk source to lookup messages by parent
--
CREATE INDEX "chat_messages_chat_id_chat_created_at"
    ON app.chat_messages (chat_id, chat_created_at);

BEGIN
CREATE SCHEMA
CREATE TABLE
CREATE INDEX
CREATE TABLE
CREATE INDEX
CREATE INDEX
```

チャットが複数日を跨る可能性もあるため、一貫性の考慮が必要です  
チャットテーブルの主キーに日付も加えています

## 動的子テーブルの作成

親テーブルを作成したので、動的パーティション作成用のプロシージャの登録

```sql
sample=# --
-- Function creates a chats partition for the given day argument
--
CREATE OR REPLACE PROCEDURE app.create_chats_partition(partition_day date)
    LANGUAGE plpgsql AS
$$
BEGIN
    EXECUTE format(
    $i$
        CREATE TABLE IF NOT EXISTS app."chats_%1$s"
        (LIKE app.chats INCLUDING DEFAULTS INCLUDING CONSTRAINTS);
    $i$, partition_day);
END;
$$;
CREATE PROCEDURE
```

データをロードした後に親テーブルにアタッチすることでインデックスを素早く作成します  
また、パーティションに日付の CHECK 制約をつけることで、親テーブルの排他ロックをなくし、ダウンタイムを減らします

チャットテーブルのパーティション作成プロシージャ

```sql
sample=# CREATE OR REPLACE PROCEDURE app.index_and_attach_chats_partition(partition_day date)
    LANGUAGE plpgsql AS
$$
BEGIN
    EXECUTE format(
    $i$
        -- now that any bulk data is loaded, setup the new partition table's pks
        ALTER TABLE app."chats_%1$s" ADD PRIMARY KEY (id, created_at);

        -- adding these check constraints means postgres can
        -- attach partitions without locking and having to scan them.
        ALTER TABLE app."chats_%1$s" ADD CONSTRAINT
               "chats_partition_by_range_check_%1$s"
           CHECK ( created_at >= DATE %1$L AND created_at < DATE %2$L );

        -- add more partition indexes here if necessary
        CREATE INDEX "chats_%1$s_created_at"
            ON app."chats_%1$s"
            USING btree(created_at)
            WITH (fillfactor=100);

        -- by "attaching" the new tables and indexes *after* the pk,
        -- indexing and check constraints verify all rows,
        -- no scan checks or locks are necessary, attachment is very fast,
        -- and queries to parent are not blocked.
        ALTER TABLE app.chats
            ATTACH PARTITION app."chats_%1$s"
        FOR VALUES FROM (%1$L) TO (%2$L);

        -- You now also "attach" any indexes you made at this point
        ALTER INDEX app."chats_created_at"
$$;;partition_day, (partition_day + interval '1 day')::date);o the same checkd
CREATE PROCEDURE
```

チャットメッセージテーブルのパーティション作成プロシージャ

```sql
--
-- Function indexes and attaches one day's worth of chat_messages to parent table
--
CREATE OR REPLACE PROCEDURE app.index_and_attach_chat_messages_partition(partition_day date)
    LANGUAGE plpgsql AS
$$
BEGIN
    EXECUTE format(
    $i$
        -- now that any bulk data is loaded, setup the new partition table's pks
        ALTER TABLE app."chat_messages_%1$s" ADD PRIMARY KEY (id, created_at);

        -- here's where you create per-partition indexes on the partitions
        CREATE INDEX "chat_messages_%1$s_created_at"
            ON app."chat_messages_%1$s"
            USING btree(created_at)
            WITH (fillfactor=100);

        CREATE INDEX "chat_messages_%1$s_chat_id_chat_created_at"
            ON app."chat_messages_%1$s"
            USING btree(chat_id, chat_created_at)
            WITH (fillfactor=100);

        -- add more partition indexes here if necessary

        -- by "attaching" the new tables and indexes *after* the pk,
        -- indexing and check constraints verify all rows,
        -- no scan checks or locks are necessary, attachment is very fast,
        -- and queries to parent are not blocked.
        ALTER TABLE app.chat_messages
            ATTACH PARTITION app."chat_messages_%1$s"
        FOR VALUES FROM (%1$L) TO (%2$L);

        -- You now also "attach" any indexes you made at this point
        ALTER INDEX app."chat_messages_created_at"
            ATTACH PARTITION app."chat_messages_%1$s_created_at";

        ALTER INDEX app."chat_messages_chat_id_chat_created_at"
            ATTACH PARTITION app."chat_messages_%1$s_chat_id_chat_created_at";

        -- Droping the now unnecessary check constraints they were just needed
        -- to prevent the attachment from forcing a scan to do the same check
        ALTER TABLE app."chat_messages_%1$s" DROP CONSTRAINT
            "chat_messages_partition_by_range_check_%1$s";
    $i$,
    partition_day, (partition_day + interval '1 day')::date);
END;
$$;
```

## 大きなテーブルからのデータの段階的なコピー

「大きなテーブル」から新しいパーティション スキームにデータをコピーするための最後の手順セットを作成します

チャットテーブルのコピープロシージャ

```sql
sample=# --
-- Function copies one day's worth of chats rows from old "large"
-- table new partition.  Note that the copied data is ordered by
-- created_at, this improves block cache density.
--
CREATE OR REPLACE PROCEDURE app.copy_chats_partition(partition_day date)
    LANGUAGE plpgsql AS
$$
DECLARE
    num_copied bigint = 0;
BEGIN
    EXECUTE format(
    $i$
        INSERT INTO app."chats_%1$s" (id, created_at)
        SELECT id, created_at FROM chats
        WHERE created_at::date >= %1$L::date AND created_at::date < (%1$L::date + interval '1 day')
        ORDER BY created_at
    $i$, partition_day);
    GET DIAGNOSTICS num_copied = ROW_COUNT;
    RAISE NOTICE 'Copied % rows to %', num_copied, format('app."chats_%1$s"', partition_day);
END;
$$;
CREATE PROCEDURE
```

チャットメッセージテーブルのコピープロシージャ

```Sql
--
-- Function copies one day's worth of chat_messages rows from old
-- "large" table new partition.  Note that the data is ordered by
-- chat_id then created_at, this improves block cache density.
--
CREATE OR REPLACE PROCEDURE app.copy_chat_messages_partition(partition_day date)
    LANGUAGE plpgsql AS
$$
DECLARE
    num_copied bigint = 0;
BEGIN
    EXECUTE format(
    $i$
        INSERT INTO app."chat_messages_%1$s" (id, created_at, chat_id, chat_created_at, message)
        SELECT m.id, m.created_at, c.id, c.created_at, m.message FROM chat_messages m JOIN chats c on (c.id = m.chat_id)
        WHERE m.created_at::date >= %1$L::date AND m.created_at::date < (%1$L::date + interval '1 day')
        ORDER BY chat_id, m.created_at
    $i$, partition_day);
    GET DIAGNOSTICS num_copied = ROW_COUNT;
    RAISE NOTICE 'Copied % rows to %', num_copied, format('app."chat_messages_%1$s"', partition_day);
END;
$$;
```

## すべてをまとめる(create copy index attach)

最後の手順は、すべてをまとめてパーティションを作成し、古いデータを新しいテーブルにコピーし、新しいテーブルにインデックスを付けて、それを親にアタッチするラッパーです。

新しい日付から古い日付の順にデータコピーすることで、すぐに新しい日付のデータが扱えるようになります

チャットテーブルのロード用プロシージャの作成

```sql
sample=# --
-- Wrappe--function to create, copy, index and attach a given day.
-- Wrapper function to create, copy, index and attach a given day.
--EATE OR REPLACE PROCEDURE app.load_chats_partition(i date)
CREATE OR REPLACE PROCEDURE app.load_chats_partition(i date)
    LANGUAGE plpgsql AS
$$GIN
BEGINALL app.create_chats_partition(i);
    CALL app.create_chats_partition(i);
    CALL app.copy_chats_partition(i);artition(i);
    CALL app.index_and_attach_chats_partition(i);
END;
$$;
-- This procedure loops over all days in the old table, copying each day
-- This procedure loops over all days in the old table, copying each day
-- and then committing the transaction.
--EATE OR REPLACE PROCEDURE app.load_chats_partitions()
CREATE OR REPLACE PROCEDURE app.load_chats_partitions()
    LANGUAGE plpgsql AS
$$CLARE
DECLARErt_date date;
    start_date date;
    end_date date;
    i date;
BEGINELECT min(created_at)::date INTO start_date FROM chats;
    SELECT min(created_at)::date INTO start_date FROM chats;
    SELECT max(created_at)::date INTO end_date FROM chats;_date, interval '-1 day') LOOP
    FOR i IN SELECT * FROM generate_series(end_date, start_date, interval '-1 day') LOOP
        CALL app.load_chats_partition(i);
        COMMIT;
    END LOOP;
END;
$$;
CREATE PROCEDURE
CREATE PROCEDURE
```

チャットメッセージテーブルのロード用プロシージャの作成

```sql
--
-- Wrapper function loops over all days in large table, creating new
-- partions, copying them, then indexing and attaching them.
--
CREATE OR REPLACE PROCEDURE app.load_chat_messages_partition(i date)
    LANGUAGE plpgsql AS
$$
BEGIN
    CALL app.create_chat_messages_partition(i);
    CALL app.copy_chat_messages_partition(i);
    CALL app.index_and_attach_chat_messages_partition(i);
    COMMIT;
END;
$$;
CREATE OR REPLACE PROCEDURE app.load_chat_messages_partitions()
    LANGUAGE plpgsql AS
$$
DECLARE
    start_date date;
    end_date date;
    i date;
BEGIN
    SELECT min(created_at)::date INTO start_date FROM chat_messages;
    SELECT max(created_at)::date INTO end_date FROM chat_messages;
    FOR i IN SELECT * FROM generate_series(end_date, start_date, interval '-1 day') LOOP
        CALL app.load_chat_messages_partition(i);
    END LOOP;
END;
$$;
CREATE PROCEDURE
CREATE PROCEDURE
```

最後に、プロシージャを呼び出してプロセス全体を開始します

```sql
CALL app.load_chats_partitions();
CALL app.load_chat_messages_partitions();

NOTICE:  Copied 16584 rows to app."chat_messages_2022-01-31"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-30"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-29"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-28"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-27"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-26"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-25"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-24"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-23"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-22"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-21"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-20"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-19"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-18"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-17"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-16"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-15"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-14"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-13"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-12"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-11"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-10"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-09"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-08"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-07"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-06"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-05"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-04"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-03"
NOTICE:  Copied 34584 rows to app."chat_messages_2022-01-02"
NOTICE:  Copied 18000 rows to app."chat_messages_2022-01-01"
CALL
```

## パーティションを作成するための毎日の Cron ジョブの設定

```Sql
sample=# CREATE OR REPLACE PROCEDURE app.create_daily_partition(today date)
    LANGUAGE plpgsql AS
$$
BEGIN
    CALL app.create_chats_partition(today);
    CALL app.create_chat_messages_partition(today);
END;
$$;
CREATE PROCEDURE
```

```Sql
sample=# SELECT cron.schedule('new-chat-partition', '0 23 * * *', 'CALL app.create_daily_partition(now()::date + ''interval 1 day'')');
 schedule
----------
        1
(1 row)
```

パーティションテーブルの情報は次のようになっています

```sql
sample=# select pt.relnamespace::regnamespace::text as schema,
base_tb.relname as parent_table_name,
pt.relname as table_name,
pg_get_partkeydef(base_tb.oid) as partition_key,
pg_get_expr(pt.relpartbound, pt.oid, true) as partition_expression
from
pg_class base_tb
join pg_inherits i on i.inhparent = base_tb.oid
join pg_class pt on pt.oid = i.inhrelid;
sample=# SELECT partrelid::regclass, * FROM pg_partitioned_table ;
     partrelid     | partrelid | partstrat | partnatts | partdefid | partattrs | partclass | partcollation | partexprs
-------------------+-----------+-----------+-----------+-----------+-----------+-----------+---------------+-----------
 app.chats         |     17114 | r         |         1 |         0 | 2         | 3127      | 0             |
 app.chat_messages |     17123 | r         |         1 |         0 | 2         | 3127      | 0             |
(2 rows)

sample=# SELECT
    nmsp_parent.nspname AS parent_schema,
    parent.relname      AS parent,
    nmsp_child.nspname  AS child_schema,
    child.relname       AS child
FROM pg_inherits
    JOIN pg_class parent            ON pg_inherits.inhparent = parent.oid
    JOIN pg_class child             ON pg_inherits.inhrelid   = child.oid
    JOIN pg_namespace nmsp_parent   ON nmsp_parent.oid  = parent.relnamespace
    JOIN pg_namespace nmsp_child    ON nmsp_child.oid   = child.relnamespace
WHERE parent.relname in ('chats','chat_messages');

parent_schema |    parent     | child_schema |          child
---------------+---------------+--------------+--------------------------
 app           | chats         | app          | chats_2022-01-30
 app           | chats         | app          | chats_2022-01-29
 app           | chats         | app          | chats_2022-01-28
 app           | chats         | app          | chats_2022-01-27
 app           | chats         | app          | chats_2022-01-26
 app           | chats         | app          | chats_2022-01-25
 app           | chats         | app          | chats_2022-01-24
 app           | chats         | app          | chats_2022-01-23
 app           | chats         | app          | chats_2022-01-22
 app           | chats         | app          | chats_2022-01-21
 app           | chats         | app          | chats_2022-01-20
 app           | chats         | app          | chats_2022-01-19
 app           | chats         | app          | chats_2022-01-18
 app           | chats         | app          | chats_2022-01-17
 app           | chats         | app          | chats_2022-01-16
 app           | chats         | app          | chats_2022-01-15
 app           | chats         | app          | chats_2022-01-14
 app           | chats         | app          | chats_2022-01-13
 app           | chats         | app          | chats_2022-01-12
 app           | chats         | app          | chats_2022-01-11
 app           | chats         | app          | chats_2022-01-10
 app           | chats         | app          | chats_2022-01-09
 app           | chats         | app          | chats_2022-01-08
 app           | chats         | app          | chats_2022-01-07
 app           | chats         | app          | chats_2022-01-06
 app           | chats         | app          | chats_2022-01-05
 app           | chats         | app          | chats_2022-01-04
 app           | chats         | app          | chats_2022-01-03
 app           | chats         | app          | chats_2022-01-02
 app           | chats         | app          | chats_2022-01-01
 app           | chat_messages | app          | chat_messages_2022-01-31
 app           | chat_messages | app          | chat_messages_2022-01-30
 app           | chat_messages | app          | chat_messages_2022-01-29
 app           | chat_messages | app          | chat_messages_2022-01-28
 app           | chat_messages | app          | chat_messages_2022-01-27
 app           | chat_messages | app          | chat_messages_2022-01-26
 app           | chat_messages | app          | chat_messages_2022-01-25
 app           | chat_messages | app          | chat_messages_2022-01-24
 app           | chat_messages | app          | chat_messages_2022-01-23
 app           | chat_messages | app          | chat_messages_2022-01-22
 app           | chat_messages | app          | chat_messages_2022-01-21
 app           | chat_messages | app          | chat_messages_2022-01-20
 app           | chat_messages | app          | chat_messages_2022-01-19
 app           | chat_messages | app          | chat_messages_2022-01-18
 app           | chat_messages | app          | chat_messages_2022-01-17
 app           | chat_messages | app          | chat_messages_2022-01-16
 app           | chat_messages | app          | chat_messages_2022-01-15
 app           | chat_messages | app          | chat_messages_2022-01-14
 app           | chat_messages | app          | chat_messages_2022-01-13
 app           | chat_messages | app          | chat_messages_2022-01-12
 app           | chat_messages | app          | chat_messages_2022-01-11
 app           | chat_messages | app          | chat_messages_2022-01-10
 app           | chat_messages | app          | chat_messages_2022-01-09
 app           | chat_messages | app          | chat_messages_2022-01-08
 app           | chat_messages | app          | chat_messages_2022-01-07
 app           | chat_messages | app          | chat_messages_2022-01-06
 app           | chat_messages | app          | chat_messages_2022-01-05
 app           | chat_messages | app          | chat_messages_2022-01-04
 app           | chat_messages | app          | chat_messages_2022-01-03
 app           | chat_messages | app          | chat_messages_2022-01-02
 app           | chat_messages | app          | chat_messages_2022-01-01
(61 rows)
```

```sql
sample=# select count(*) from app."chats_2022-01-01";
 count
-------
    24
(1 row)

sample=# select count(*) from app."chats_2022-01-02";
 count
-------
    24
(1 row)

sample=# select count(*) from app."chat_messages_2022-01-01";
 count
-------
 18000
(1 row)

sample=# select count(*) from app."chat_messages_2022-01-02";
 count
-------
 34584
(1 row)
```

その他参考

https://www.crunchydata.com/blog/five-great-features-of-postgres-partition-manager
