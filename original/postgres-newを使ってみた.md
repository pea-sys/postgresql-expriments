### postgres-new とは？

supabase の AI 支援付き postgreSQL のサンドボックスです。

https://github.com/supabase-community/postgres-new

こちらから使用できます(GitHub アカウント連携が必要ですが無料)。

https://postgres.new/

赤枠部にテキストを入力することで、AI の支援が受けられます。
![1.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/383255/0f1ae526-b2f2-fd19-3f2f-570609a49a92.png)

本記事より詳細なプロモーションビデオ

https://www.youtube.com/watch?v=ooWaPVvljlU

---

- データベースの作成

  - 入力例

  ```
  勤怠システムのデータベースを作成してください

  ```

  - 応答例

  ```
  勤怠システムのデータベースを作成するために、以下のようなテーブルを設計します：

  従業員 (employees)
  勤怠記録 (attendance_records)
  部署 (departments)
  従業員 (employees)
  id: bigint primary key generated always as identity
  name: text
  email: text
  department_id: bigint (外部キー: departments.id)
  hire_date: date
  勤怠記録 (attendance_records)
  id: bigint primary key generated always as identity
  employee_id: bigint (外部キー: employees.id)
  date: date
  check_in: timestamp
  check_out: timestamp
  部署 (departments)
  id: bigint primary key generated always as identity
  name: text
  これらのテーブルを作成するSQLを実行します。


  Executed SQL
  勤怠システムのデータベースが正常に作成されました。以下のテーブルが含まれています：

  departments: 部署情報を格納します。
  employees: 従業員情報を格納します。
  attendance_records: 勤怠記録を格納します。
  テーブル構造
  departments
  id: bigint primary key generated always as identity
  name: text
  employees
  id: bigint primary key generated always as identity
  name: text
  email: text
  department_id: bigint (外部キー: departments.id)
  hire_date: date
  attendance_records
  id: bigint primary key generated always as identity
  employee_id: bigint (外部キー: employees.id)
  date: date
  check_in: timestamp
  check_out: timestamp
  次に、サンプルデータを挿入してみましょうか？
  ```

  この段階でテーブルの ER 図がつくられます。
  ![2.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/383255/825d552f-34a4-6d56-2158-96c1a19a1249.png)

  ER 図のカラムをクリックすることで、制約やインデックスの作成が出来ます。

  また、Migrations タブを開くことで生 SQL が確認できます

  ![3.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/383255/5fba0efb-30b4-bcc3-aabf-22562a2625ed.png)

  現状、大量のサンプルデータの挿入は誤った SQL を作成し
  失敗しやすいですが、小規模データは問題なさそうです。

  ![4.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/383255/3d9ad3f2-9657-3831-4c84-6547fbc26155.png)

  CSV ファイルからテーブルを作成したり、データをロードできますし、
  簡単な分析もできそうです

  ![5.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/383255/790d3970-ee94-2655-1c3e-ce652cba5e12.png)

  データベース毎の履歴からクラスターのダウンロードも可能です
  ![6.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/383255/0159326c-fd55-dfe2-4e62-f921d673841c.png)

  ダウンロードファイルの中身

  ```
  C:\Users\masami\Desktop\-1723621241654>tree /f
  フォルダー パスの一覧
  ボリューム シリアル番号は 368F-F563 です
  C:.
  │  pg_hba.conf
  │  pg_ident.conf
  │  PG_VERSION
  │  postgresql.auto.conf
  │  postgresql.conf
  │  postmaster.pid
  │
  ├─base
  │  ├─1
  │  │      112
  │  │      ・・・
  │  │      pg_filenode.map
  │  │      pg_internal.init
  │  │      PG_VERSION
  │  │
  │  └─・・・
  │
  ├─global
  │      1213
  │      ・・・
  │      pg_control
  │      pg_filenode.map
  │      pg_internal.init
  │
  ├─pg_commit_ts
  ├─pg_dynshmem
  ├─pg_logical
  │  │  replorigin_checkpoint
  │  │
  │  ├─mappings
  │  └─snapshots
  ├─pg_multixact
  │  ├─members
  │  │      0000
  │  │
  │  └─offsets
  │          0000
  │
  ├─pg_notify
  ├─pg_replslot
  ├─pg_serial
  ├─pg_snapshots
  ├─pg_stat
  ├─pg_stat_tmp
  ├─pg_subtrans
  │      0000
  │
  ├─pg_tblspc
  ├─pg_twophase
  ├─pg_wal
  │  │  000000010000000000000008
  │  │  ・・・
  │  │
  │  └─archive_status
  └─pg_xact
          0000
  ```

  設定ファイル等は環境によってチューニングが必要なので、基本的にこのまま使うことはないでしょう。postmaster.pid もない方が良いですね。

  ***

  現状、ブラウザのウィンドウサイズによっては使用できません。
  ![5.png](https://qiita-image-store.s3.ap-northeast-1.amazonaws.com/0/383255/a73cb221-a972-c57f-7934-c4dd39185c3f.png)
