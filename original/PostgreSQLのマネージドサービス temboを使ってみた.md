# PostgreSQL のマネージドサービス tembo を使ってみた

tembo は Postgres のマネージドサービスです。

https://tembo.io/docs

現時点では無料枠はクレカ登録不要で使えます。  
現在は次のユースケースに合わせたインスタンスを提供しています。

| Stack                         | Replacement for             |
| ----------------------------- | --------------------------- |
| Standard                      | Amazon RDS                  |
| OLTP                          | Amazon RDS                  |
| Message Queue                 | Amazon SQS, RabbitMQ, Redis |
| Mongo Alternative on Postgres | MongoDB                     |
| Vector DB                     | Pinecone, Weaviate          |
| RAG                           | LangChain                   |
| Machine Learning              | MindsDB                     |
| OLAP                          | Snowflake, Bigquery         |
| Data Warehouse                | Snowflake, Bigquery         |
| Geospatial                    | ESRI, Oracle                |
| Time Series                   | InfluxDB, TimescaleDB       |

次のように GUI 操作で選択できます

![cloud tembo io_orgs_org_2kmfcbwfEEXLG6mMow4nF5kLFBJ_clusters_new_select-type](https://github.com/user-attachments/assets/fc21c9d8-95c6-44dd-b060-96bceff59358)

今回は OLTP を選択します。  
機能が制限されますが、無料枠でデプロイします。
![2](https://github.com/user-attachments/assets/7a1de70f-bd48-4f55-acdc-0721a5bc98d2)

デプロイした postgres サーバーにアクセスするためのクライアントを用意します。  
tembo にアクセスするクライアントは SNI をサポートしている必要があります。  
psql はデフォルトでサポートしているため、psql を使用します。  
ここでは、WSL2 を使用します。

SSL 接続するため、PostgreSQL の公式リポジトリの署名キーをダウンロードします。

```bash
sudo apt-get update && sudo apt-get install -y lsb-release
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null
sudo apt-get update && sudo apt-get install -y postgresql-client
```

インスタンスが立ち上げ後、Dashboard で postgres サーバ接続文字列を確認します。
![3](https://github.com/user-attachments/assets/64a48e2e-ea02-46cd-88b1-804a2acf8da6)

接続文字列をクリップボードにコピーします
![3](https://github.com/user-attachments/assets/a8b4c4df-2846-4a1b-b320-05fe3bf52cbb)

これを psql のパラメータに渡します。

```
psql -U postgres 'postgresql://postgres:YjGD7QtSQNVNywr9@sociably-scrupulous-protozoa.data-1.use1.tembo.io:5432/postgres'
psql (16.3 (Ubuntu 16.3-1.pgdg24.04+1), server 15.7)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
Type "help" for help.
```

postgres のバージョンは 15.7 のようです。

適当なクエリを実行してみます

```sql
postgres=# CREATE OR REPLACE FUNCTION generate_random_string(
  length INTEGER,
  characters TEXT default '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
) RETURNS TEXT AS
$$
DECLARE
  result TEXT := '';
BEGIN
  IF length < 1 then
      RAISE EXCEPTION 'Invalid length';
  END IF;
  FOR __ IN 1..length LOOP
    result := result || substr(characters, floor(random() * length(characters))::int + 1, 1);
  end loop;
  RETURN result;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION
postgres=# CREATE TABLE t (
    id int,
    happened_at timestamptz,
    padding text
);
CREATE TABLE
postgres=# INSERT INTO t (
    id,
    happened_at,
    padding
)
SELECT
    n,
    '2023-01-01 UTC'::timestamptz + (interval '1 second' * n),
    generate_random_string(1000)
FROM
    generate_series(1, 1000000) as n;

INSERT 0 1000000
```

実行後のダッシュボードの状況  
![dashboard](https://github.com/user-attachments/assets/acf4833a-56e3-4c94-9a61-32929e1f58c3)

Postgres の一部の設定(`max_connections, shared_buffers, work_mem, maintenance_work_mem, effective_cache_size`etc)は変更可能です。また、任意の設定を追加することが出来ます。

また、コネクションプーリング等の一部の拡張機能がボタン１つで適用できるようになっています。

![3](https://github.com/user-attachments/assets/88d7073f-a3fe-46b3-8f94-5a72428daa69)

PostgreSQL のマネージドサービスが、無料で使用できるので、ちょっとした実験をするのに便利そうですね。

※まだ若いサービスなので、いくつか問題を見つけましたがこれからに期待です。
