# Windows10でpgAgentを使ってみる

pgAgentはPostgres データベース用のジョブスケジューリングエージェントです。
### [インストール]
ApplicationStackBuilderを使用してインストールします  
![Install](https://github.com/pea-sys/postgresql-expriments/assets/49807271/8987f2d4-89e6-4fe0-af1b-7fa8929067b5)
* DBにアクセスするユーザーの入力

![インストール2](https://github.com/pea-sys/postgresql-expriments/assets/49807271/e618b9b9-adf5-41de-9fa1-0eac164915d3)

* pgAgentサービスを起動するアカウントの設定

![インストール3](https://github.com/pea-sys/postgresql-expriments/assets/49807271/dd0d8b77-dcfe-41cd-8088-fd79426a9c60)


* インストール設定が合っていれば、下記のクエリが成功します
```sql
C:\Users\masami>psql -U postgres -d postgres
psql (16.0)
"help"でヘルプを表示します。

postgres=# select * from pgagent.pga_joblog order by jlgstart desc limit 1;
 jlgid | jlgjobid | jlgstatus | jlgstart | jlgduration
-------+----------+-----------+----------+-------------
(0 行)
```

### [ジョブ登録]
* PgAdminを起動します
* pgAgent Jobsを右クリックして [Create] ->  [pgAgent Job...] を選択

![1](https://github.com/pea-sys/postgresql-expriments/assets/49807271/4b8b030b-984a-429e-95ea-5db9eeb81c16)

* ジョブ名称を入力

![2](https://github.com/pea-sys/postgresql-expriments/assets/49807271/45b6dcef-3707-4979-99c2-2677f8e2f8ae)

* Stepsタブに移動し、ステップ名称と実行クエリを入力する

![3](https://github.com/pea-sys/postgresql-expriments/assets/49807271/de8a0b8a-2cb8-40a2-8df7-792ec8a21c5c)

* Schedulersタブに移動し、実行スケジュールを登録します

![4](https://github.com/pea-sys/postgresql-expriments/assets/49807271/bcc6f043-adba-4a26-9016-5fce1df85b27)

* ジョブの実行結果を確認します  
定期実行はできているか、失敗している

```sql
postgres=# select * from pgagent.pga_joblog order by jlgstart desc limit 1;
 jlgid | jlgjobid | jlgstatus |           jlgstart            |   jlgduration
-------+----------+-----------+-------------------------------+-----------------
    32 |        3 | f         | 2023-10-27 12:54:02.300087+00 | 00:00:00.057918
(1 行)


postgres=# select * from pgagent.pga_joblog order by jlgstart desc limit 1;
 jlgid | jlgjobid | jlgstatus |           jlgstart            |   jlgduration
-------+----------+-----------+-------------------------------+-----------------
    36 |        3 | s         | 2023-10-27 12:58:00.369421+00 | 00:00:00.056415
```
