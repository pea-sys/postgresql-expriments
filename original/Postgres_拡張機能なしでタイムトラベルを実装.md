# Postgres 拡張機能なしでタイムトラベルを実装

https://proopensource.it/blog/postgresql-time-travel

### 主キーテーブル

まず、すべてのパーティションで一意である必要があるため、一意の数値識別子を保持するテーブルが必要です。

```sql
sample=# CREATE TABLE timetravel_pk (
  timetravelid BIGINT GENERATED ALWAYS AS IDENTITY,
  created TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT timetravle_pk_pk PRIMARY KEY (timetravelid)
);
CREATE TABLE
```

### データテーブル

データ テーブルは範囲別にパーティション分割されます。この例では、年別にパーティション分割されます。

```sql
sample=# -- Creates the btree GIST index which will be used for the column changed
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Creates the partitioned table which will store all versions of records
CREATE TABLE timetravel (
  timetravelid BIGINT NOT NULL,
  changed TSTZRANGE NOT NULL DEFAULT tstzrange(clock_timestamp(), 'INFINITY', '[)'),
  data_text TEXT,
  data_json JSONB,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT timetravelid_fk FOREIGN KEY (timetravelid) REFERENCES timetravel_pk(timetravelid)
) PARTITION BY RANGE (lower(changed))
;

-- Creating indexes
CREATE INDEX timetravel_changed_idx
        ON timetravel
        USING gist
        (changed)
;

CREATE INDEX timetravel_timetravelid_fk_idx
        ON timetravel
        USING btree
        (timetravelid)
;

CREATE INDEX timetravel_not_deleted_idx
  ON timetravel
  USING btree
; WHERE NOT deleted
CREATE EXTENSION
CREATE TABLE
CREATE INDEX
CREATE INDEX
CREATE INDEX
```

### 時間範囲表

テーブルを自動的にパーティション分割するには、どの年のパーティションがすでに存在しているかを知る必要があります。パーティションが存在しない場合は、新しいパーティションを作成する必要があります。
トリガーは、挿入の前と更新の前に起動されます。

期間を保存するためのテーブルを作成する

```sql
sample=# CREATE TABLE timetravel_part_vals (
  part_year SMALLINT NOT NULL,
  start_value TIMESTAMP WITH TIME ZONE NOT NULL,
  end_value TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT timetravel_part_vals_pk PRIMARY KEY (part_year)
);
CREATE TABLE
```

### 新しいパーティションを処理する関数

通常、パーティションの自動作成は、たとえば pg_cron を使用した cron ジョブで時間ごとに処理します。

```sql
sample=# CREATE OR REPLACE FUNCTION timetravel_partition (in_changed TIMESTAMPTZ)
  RETURNS void
  LANGUAGE PLPGSQL
  AS
$$
DECLARE
  query TEXT;
  in_range BOOLEAN = FALSE;
  year_p SMALLINT;
  start_v TIMESTAMP WITH TIME ZONE;
  end_v TIMESTAMP WITH TIME ZONE;
  part_name TEXT;
BEGIN
  -- Check the changed date to be in an existing partition
  EXECUTE 'SELECT count(*) > 0
  FROM timetravel_part_vals
  WHERE part_year = extract(year from $1)'
  INTO in_range
  USING in_changed;

  IF (NOT in_range) THEN
    -- Update the range data
    EXECUTE 'INSERT INTO timetravel_part_vals (part_year, start_value, end_value)
    SELECT extract(year from $1),
      date_trunc(''year'', $1),
      date_trunc(''year'', $1) + INTERVAL ''1 year''
    RETURNING *'
    INTO year_p, start_v, end_v
    USING in_changed;

    -- Create a new partition
    part_name := 'timetravel_' || year_p::TEXT;

    EXECUTE 'CREATE TABLE ' || part_name ||
      ' PARTITION OF timetravel FOR VALUES FROM (''' || start_v::text || ''') TO (''' || end_v::text || ''')';

    RAISE NOTICE 'Partition % created.', part_name;

  END IF;
END;
$$;
CREATE FUNCTION
sample=# SELECT timetravel_partition (now());
NOTICE:  Partition timetravel_2024 created.
 timetravel_partition
----------------------

(1 row)
```

### INSERT と UPDATE を処理するトリガー

挿入と更新のトリガー関数は常に変更タイムスタンプの受信値を上書きするため、データが操作されることはありません。

```sql
sample=# CREATE OR REPLACE FUNCTION trigger_timetravel_in_upd ()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
  -- Setting default values
  NEW.deleted = false;
  NEW.changed = tstzrange(clock_timestamp(), 'INFINITY', '[)');

  -- On UPDATE a new record is inserted
  CASE WHEN TG_OP = 'UPDATE' THEN

    IF NEW.timetravelid <> OLD.timetravelid THEN
      RAISE EXCEPTION 'The identity column timetravelid can not be changed!';
    END IF;

    IF NOT OLD.deleted THEN
      IF upper(OLD.changed) = 'infinity' THEN
        -- Updated the latest version of a record
        INSERT INTO timetravel (timetravelid, data_text, data_json, changed)
        SELECT NEW.timetravelid
          , NEW.data_text
          , NEW.data_json
          , NEW.changed
        ;

        -- Only the range for the old record is changed, it has an end now
        NEW.data_text = OLD.data_text;
        NEW.data_json = OLD.data_json;
        NEW.changed = tstzrange(lower(OLD.changed), lower(NEW.changed));

        RETURN NEW;
      ELSE
	      -- It is not the newest version, therefore there is nothing to do
        RETURN NULL;
      END IF;
    ELSE
      -- An already deleted record cannot be changed
      RETURN NULL;
    END IF;

  -- The new record needs its id created by inserting into the pk table
  WHEN TG_OP = 'INSERT' THEN
    INSERT INTO timetravel_pk (created)
      VALUES (clock_timestamp())
      RETURNING timetravelid
      INTO NEW.timetravelid;

  	RETURN NEW;
  ELSE
    RETURN NULL;
  END CASE;
END;
$$;
CREATE FUNCTION

sample=# -- Attach the trigger function for inserts
CREATE TRIGGER timetravel_insert
  BEFORE INSERT
  ON timetravel
  FOR EACH ROW
  WHEN (pg_trigger_depth() < 1)
  EXECUTE PROCEDURE trigger_timetravel_in_upd()
;

-- Attach the trigger function for updates
CREATE TRIGGER timetravel_update
  BEFORE UPDATE
  ON timetravel
  FOR EACH ROW
  EXECUTE PROCEDURE trigger_timetravel_in_upd()
;
CREATE TRIGGER
CREATE TRIGGER
```

### 削除のきっかけ

最後に注意しなければならないのは、削除されたレコードです。データは論理的にしか削除できません。

```sql
-- The trigger inserts two records, one with the old data but with an end
-- timestamp in column changed, one with deleted = true but end timestamp
-- is INFINITY
CREATE OR REPLACE FUNCTION trigger_timetravel_del ()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
DECLARE
  ts timestamp with time zone;
BEGIN
  -- When a record has already been deleted, an error is raised and no data is changed
  IF OLD.deleted THEN
     RAISE EXCEPTION 'Timetravel record with the timetravelid % is already deleted.', OLD.timetravelid;
  END IF;

  IF upper(OLD.changed) = 'infinity' THEN
  -- Only the latest version has to be taken care off
    ts = clock_timestamp();

    INSERT INTO timetravel (timetravelid, changed, data_text, data_json, deleted)
    VALUES (
      OLD.timetravelid,
      tstzrange(ts, 'INFINITY'),
      OLD.data_text,
      OLD.data_json,
      true
    ),
    (
      OLD.timetravelid,
      tstzrange(lower(OLD.changed), ts),
      OLD.data_text,
      OLD.data_json,
      false
    );

    RETURN OLD;
  ELSE
    -- All other records stay as they are
    RETURN NULL;
  END IF;
END;
$$;
CREATE FUNCTION

sample=# -- Attach the trigger function for deletions
CREATE TRIGGER timetravel_delete
  BEFORE DELETE
  ON timetravel
  FOR EACH ROW
  EXECUTE PROCEDURE trigger_timetravel_del()
;
CREATE TRIGGER
```

### データの挿入

タイムトラベルをするには、timetravel テーブルにいくつかのデータが必要です。
このステートメントは 1,000,000 件のレコードを挿入します。

```sql
sample=# -- Insert records
INSERT INTO timetravel (data_text, data_json)
SELECT substr(md5(random()::text), 1, 25) AS data_text
        , to_jsonb(substr(md5(random()::text), 1, 25)) AS data_json
FROM generate_series(1, 100000) s(i)
;
INSERT 0 100000
```

更新により、一部のレコードがランダム ID で変更されます。各レコードの複数のバージョンを生成するために、これを複数回実行することができます。

```sql
sample=# -- Update existing records
WITH t1 AS
        (
                SELECT floor(random() * (100000-1+1) + 1)::bigint AS timetravelid
                        , substr(md5(random()::text), 1, 25) AS data_text
                        , to_jsonb(substr(md5(random()::text), 1, 25)) AS data_json
                FROM generate_series(1, 100000) s(i)
        )
, t2 AS
        (
                SELECT DISTINCT ON (timetravelid) timetravelid
                        , data_text
                        , data_json
                FROM t1
        )
UPDATE timetravel SET
        data_text = t2.data_text,
        data_json = t2.data_json
FROM t2
WHERE timetravel.timetravelid = t2.timetravelid
;
UPDATE 63213
```

データを削除します

```sql
sample=# -- Delete some records
DELETE FROM timetravel WHERE timetravelid IN (99, 654, 5698);
DELETE 3
```

### データにアクセスするための SQL 文

既存のデータ量を確認しています

```sql
sample=# -- Table statistics
WITH rec_v AS
  (
    SELECT t.timetravelid
      , ROW_NUMBER() OVER (PARTITION BY t.timetravelid ORDER BY lower(t.changed)) AS rec_version
    FROM timetravel AS t
  )
SELECT count(t.timetravelid) AS recordcount
  , min(t.timetravelid) AS min_primary_key
  , max(t.timetravelid) AS max_primary_key
  , min(rec_v.rec_version) AS min_version_number
  , max(rec_v.rec_version) AS max_version_number
  , count(t.timetravelid) FILTER (WHERE t.deleted) AS deleted_records
FROM timetravel AS t
INNER JOIN rec_v
  ON t.timetravelid = rec_v.timetravelid
;
 recordcount | min_primary_key | max_primary_key | min_version_number | max_version_number | deleted_records
-------------+-----------------+-----------------+--------------------+--------------------+-----------------
      289654 |               1 |          100000 |                  1 |                  3 |               9
(1 row)
```

特定の時点で有効なデータを取得する

```sql
sample=# -- Result for a certain point in time
SELECT t.timetravelid
  , ROW_NUMBER() OVER (PARTITION BY t.timetravelid ORDER BY lower(t.changed)) AS rec_version
  , t.data_text
  , t.data_json
  , pk.created
  , t.changed
  , lower(t.changed) AS valid_from
  , upper(t.changed) AS valid_until
  , t.deleted
FROM timetravel_pk AS pk
INNER JOIN timetravel AS t
  ON pk.timetravelid = t.timetravelid
WHERE '2024-12-11 20:53:51.671003+09'::timestamptz <@ t.changed
ORDER BY t.timetravelid
  , lower(t.changed)
;
 timetravelid | rec_version |         data_text         |          data_json          |            created            |>
--------------+-------------+---------------------------+-----------------------------+-------------------------------+>
            1 |           1 | 894759e58cada49faa08765a0 | "7a5e37bac17fd7ee1f040783e" | 2024-12-11 20:53:51.656951+09 |>
            2 |           1 | a0dd818b292846f5e4b83a4e2 | "608aafcb04e5043e120dcb80f" | 2024-12-11 20:53:51.661125+09 |>
            3 |           1 | f5e0c1bf1cd02fcc0db0680c9 | "ef1b68fe26007a483c5b3160b" | 2024-12-11 20:53:51.661346+09 |>
            4 |           1 | dee8d68492fdba0776f05dc0f | "2e0cc1ec2c4fb5c781928b0e2" | 2024-12-11 20:53:51.66144+09  |>
```

### ビュー

前のステートメントを使用してビューを作成できます。WHERE 句と ORDER BY 句のみを削除します。

```sql
sample=# CREATE OR REPLACE VIEW timetravel_v AS
WITH rec_v AS
  (
    SELECT t.timetravelid
      , ROW_NUMBER() OVER (PARTITION BY t.timetravelid ORDER BY lower(t.changed)) AS rec_version
    FROM timetravel AS t
  )
SELECT DISTINCT ON (t.timetravelid)
  t.timetravelid
  , rec_v.rec_version
  , t.data_text
  , t.data_json
  , pk.created
  , t.changed
  , lower(t.changed) AS valid_from
  , upper(t.changed) AS valid_until
FROM timetravel_pk AS pk
INNER JOIN timetravel AS t
  ON pk.timetravelid = t.timetravelid
INNER JOIN rec_v
  ON pk.timetravelid = rec_v.timetravelid
WHERE NOT deleted
AND upper(t.changed) = 'infinity'::TIMESTAMPTZ
;
CREATE VIEW
```

このビューにはまだ 1 つの問題があります。計算列があるため、新しいデータを挿入したり、既存のデータを更新したりすることはできません。これを実現するには、ビューにアタッチされたトリガーとともに実行
されるトリガー関数をさらに作成します。

```sql
sample=# -- One trigger to bind them all
CREATE OR REPLACE FUNCTION trigger_timetravel_view_in_upd_del ()
  RETURNS TRIGGER
  LANGUAGE PLPGSQL
  AS
$$
BEGIN
  CASE
    WHEN TG_OP = 'INSERT' THEN
      EXECUTE 'INSERT INTO timetravel (data_text, data_json) VALUES ($1, $2)'
        USING NEW.data_text, NEW.data_json;
    WHEN TG_OP = 'UPDATE' THEN
      EXECUTE 'UPDATE timetravel SET data_text = $1, data_json = $2 WHERE timetravelid = $3'
        USING NEW.data_text, NEW.data_json, OLD.timetravelid;
    WHEN TG_OP = 'DELETE' THEN
      EXECUTE 'DELETE FROM timetravel WHERE timetravelid = $1'
        USING OLD.timetravelid;
    ELSE
      RAISE EXCEPTION 'Operation not supported.';
  END CASE;

  RETURN NEW;
END;
$$;
CREATE FUNCTION

sample=# -- Attach the trigger function to the view
CREATE OR REPLACE TRIGGER timetravel_v_trigger
        INSTEAD OF INSERT OR UPDATE OR DELETE
        ON timetravel_v
        FOR EACH ROW
        EXECUTE PROCEDURE trigger_timetravel_view_in_upd_del ()
;
CREATE TRIGGER
```
