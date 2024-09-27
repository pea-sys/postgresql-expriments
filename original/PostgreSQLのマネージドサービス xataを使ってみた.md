# xata を使ってみた

### xata とは？

PostgreSQL のマネージドサービスです。  
Google アカウントまたは Github アカウントを使用してログインできます。  
現状、無料でサービスを利用することもできます。

https://xata.io/

似たようなサービスに supabase , neon, tembo 等 があります。  
無料枠という観点では、xata は使用できるストレージサイズが大きいです。

■ 無料枠

| 機能             | supabase   | neon       | tembo | xata                     |
| ---------------- | ---------- | ---------- | ----- | ------------------------ |
| メモリ           | 500MB      | 1GB        | 1GB   | ?                        |
| ストレージ       | 1GB        | 0.5GB      | 10GB  | 15GB(+検索エンジン 15GB) |
| ベンダーサポート | なし(有志) | なし(有志) | あり  | なし(有志)               |
| 拡張機能         | ?          | あり       | あり  | なし                     |
| ダッシュボード   | なし       | ?          | あり  | なし                     |

### ■ 利用方法

Database name を入力して Next を押します
![1](https://github.com/user-attachments/assets/d897f133-8e84-45f5-a087-5ef6aa74727e)

Credentials をダウンロードして、Continue を押します
![2](https://github.com/user-attachments/assets/a7968188-5ea5-449d-9d19-19856e288c0a)

接続方法を選択します
![3](https://github.com/user-attachments/assets/40a2c8e8-5b92-403e-b5eb-b35580546287)

接続方法が紹介されているページが表示されるので、この通りにコマンドを実行します
![5](https://github.com/user-attachments/assets/459cafa3-2770-47cb-bd8b-d2e3ac0fa081)

CLI をインストールします

```
C:\Users\masami>npm install @xata.io/cli -g

added 383 packages in 1m

135 packages are looking for funding
  run `npm fund` for details
npm notice
npm notice New minor version of npm available! 10.2.4 -> 10.8.2
npm notice Changelog: https://github.com/npm/cli/releases/tag/v10.8.2
npm notice Run npm install -g npm@10.8.2 to update!
npm notice
```

認証します

```
C:\Users\masami>xata auth login
√ Do you want to use an existing API key or create a new API key? » Use an existing API key
√ Existing API key: ... *************************************
i Checking access to the API...
✔ All set! you can now start using xata
```

プロジェクトのセットアップします

```
C:\Users\masami>xata init --db https://pea-sys-s-workspace-pnvaao.us-east-1.xata.sh/db/sample
🦋 Initializing project... We will ask you some questions.

√ Create .gitignore and ignore .env? ... yes
√ Generate code and types from your Xata database » TypeScript
√ Choose the output path for the generated code ... src/xata.ts

Setting up Xata...

Created Xata config: .xatarc

Creating .env file
  set XATA_API_KEY=xau_*********************************
  set XATA_BRANCH=main

Added .env file to .gitignore

i Running npm install --save @xata.io/client

added 2 packages, and audited 11 packages in 3s

found 0 vulnerabilities

No new migrations to pull from main branch
Generated Xata code to ./src\xata.ts

✔ Project setup with Xata 🦋

i Setup tables and columns at https://app.xata.io/workspaces/pea-sys-s-workspace-pnvaao/dbs/sample:us-east-1

i Use xata pull main to regenerate code and types from your Xata database
```

<XATA_API_KEY>を Credentials ページでダウンロードした API_KEY に書き換えてクエリを投げます

```
curl.exe --request GET --url "https://pea-sys-s-workspace-pnvaao.us-east-1.xata.sh/db/sample:main/tables/tableName/data/rec_xyz" --header "Authorization: Bearer <XATA_API_KEY>" --header "Content-Type:
application/json"
{"id":"27169203-012f-9247-a9c8-d4c6c3a2d2ed","message":"table [sample:main/tableName] not found"}
```

クエリの実行結果が取得できています

Credentials ページで Finish ボタンを押すと、プロジェクトページに遷移します
![5](https://github.com/user-attachments/assets/c733504c-3f19-4b86-9f94-e6a8c049de62)

中央の Start with sample data を押します  
データが作成されると、テーブルが表示されます
![6](https://github.com/user-attachments/assets/aa6a79e3-3e3d-46eb-b3cc-b59fdaf57fa8)

右上の Get code snippet をクリックし、Get one record のスニペットをコピーします

![7](https://github.com/user-attachments/assets/72572050-edd2-44fe-a63c-f15baaf78316)

rec_xyz の部分を実際に存在するレコードの ID データに書き換えます。

```
curl.exe --request GET --url "https://pea-sys-s-workspace-pnvaao.us-east-1.xata.sh/db/sample:main/tables/tag/data/aiden" --header "Authorization: Bearer <XATA_API_KEY>" --header "Content-Type: applicat
ion/json"
{"id":"aiden","name":"vobis suppellex turpis 🎨 adsidue approbo ambitus soleo tactus cogo vulgivagus thorax vitium vulgivagus ubi 🦜 at amissio vigilo cohibeo","xata":{"createdAt":"2024-08-23T22:20:48.979157Z","updatedAt":"2024-08-23T22:20:48.979157Z","version":0}}
```

ブラウザからクエリも実行できます。  
現状、EXPLAIN 等の一部クエリがサポートされていません。

![8](https://github.com/user-attachments/assets/68d7e20c-da68-425e-8d1c-01157776ca0b)

クエリの制限を独自インターフェースによって狭められるてしまうので、個人的に psql から生クエリを実行したいところですが、今のところ Beta 版のようです。

https://xata.io/docs/postgres

アカウントトップページの Settings から Delete workspace を実行することでワークスペースを削除できます。
![7](https://github.com/user-attachments/assets/ece07ee7-897c-41f7-a5ba-3409db1bca90)
