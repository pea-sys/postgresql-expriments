RLS の学習に丁度良い教材があったのでやってみました。  
スキーマ分割より細かくセキュリティポリシーが設定できて、柔軟性も高いと感じました。一方で、モノリスなアプリだとチームメンバー全員に RLS を使えないまでも理解はしてもらう必要があります。  
パフォーマンスについては、別途検証する必要はあります。

https://www.tangramvision.com/blog/hands-on-with-postgresql-authorization-part-1-roles-and-grants

https://www.tangramvision.com/blog/hands-on-with-postgresql-authorization-part-2-row-level-security

本チュートリアルでは認証の実践と題して、BandCamp のような Web アプリを想定し、PostgreSQL 上で認証と RLS によるデータの保存を行うようですね。

https://bandcamp.com/

bandcamp は、曲の販売や再生が可能なサイトです。

---

元ネタは docker を使用していますが、私はローカル環境で実施します。

```
Users/masami » createdb -U postgres sample
Users/masami » psql -U postgres sample
psql (16.4 (Ubuntu 16.4-1.pgdg24.04+1))
Type "help" for help.
```

### サンプルデータ作成

```sql
sample=# CREATE TABLE artists (
    -- More about identity column:
    -- https://www.2ndquadrant.com/en/blog/postgresql-10-identity-columns/
    -- https://www.depesz.com/2017/04/10/waiting-for-postgresql-10-identity-columns/
    artist_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE albums (
    album_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    artist_id INTEGER REFERENCES artists(artist_id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    released DATE NOT NULL
);

CREATE TABLE fans (
    fan_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
);

CREATE TABLE fan_follows (
    fan_id INTEGER REFERENCES fans(fan_id) ON DELETE CASCADE,
    artist_id INTEGER REFERENCES artists(artist_id) ON DELETE CASCADE,
    PRIMARY KEY (fan_id, artist_id)
);
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE

```

### ROLE の作成

初期のロールを確認すると、スーパーユーザーは RLS をバイパスします

```sql
sample=# \du
                             List of roles
 Role name |                         Attributes
-----------+------------------------------------------------------------
 maybe     | Superuser
 mon       |
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS

sample=# SELECT current_user, session_user;
 current_user | session_user
--------------+--------------
 postgres     | postgres
(1 row)
```

ファンとアーティストのロールを追加

```Sql
sample=# CREATE ROLE fan LOGIN;
CREATE ROLE
sample=# CREATE ROLE artist LOGIN;
CREATE ROLE
sample=# SET ROLE fan;
SET
sample=> SELECT current_user, session_user;
 current_user | session_user
--------------+--------------
 fan          | postgres
(1 row)

sample=> RESET ROLE;
RESET
sample=# SELECT current_user, session_user;
 current_user | session_user
--------------+--------------
 postgres     | postgres
(1 row)

sample=# \c - artist
You are now connected to database "sample" as user "artist".
sample=> SELECT current_user, session_user;
 current_user | session_user
--------------+--------------
 artist       | artist
(1 row)

sample=> SET ROLE fan;
ERROR:  permission denied to set role "fan"
```

スーパーユーザー以外のユーザーは他のロールに変更できません。

```Sql
sample=> SET ROLE artist;
SET
sample=> SELECT * from artists;
ERROR:  permission denied for table artists
```

追加したロールの権限設定を行っていない状態です。

### Privileges と権限

スーパーユーザー以外はユーザー定義テーブルにアクセスできないことを確認します。

```
sample=> \dp
                                      Access privileges
 Schema |         Name          |   Type   | Access privileges | Column privileges | Policies
--------+-----------------------+----------+-------------------+-------------------+----------
 public | albums                | table    |                   |                   |
 public | albums_album_id_seq   | sequence |                   |                   |
 public | artists               | table    |                   |                   |
 public | artists_artist_id_seq | sequence |                   |                   |
 public | fan_follows           | table    |                   |                   |
 public | fans                  | table    |                   |                   |
 public | fans_fan_id_seq       | sequence |                   |                   |
(7 rows)

sample=>  \dt
            List of relations
 Schema |    Name     | Type  |  Owner
--------+-------------+-------+----------
 public | albums      | table | postgres
 public | artists     | table | postgres
 public | fan_follows | table | postgres
 public | fans        | table | postgres
(4 rows)
```

アーティストにアーティストテーブルの SELECT 権限を付与します

```Sql
sample=> \c - postgres
You are now connected to database "sample" as user "postgres".
sample=# GRANT SELECT ON artists TO artist;
GRANT
sample=# SET ROLE artist;
SET
sample=> SELECT * FROM artists;
 artist_id | name
-----------+------
(0 rows)

sample=> \dp
                                          Access privileges
 Schema |         Name          |   Type   |     Access privileges     | Column privileges | Policies
--------+-----------------------+----------+---------------------------+-------------------+----------
 public | albums                | table    |                           |                   |
 public | albums_album_id_seq   | sequence |                           |                   |
 public | artists               | table    | postgres=arwdDxt/postgres+|                   |
        |                       |          | artist=r/postgres         |                   |
 public | artists_artist_id_seq | sequence |                           |                   |
 public | fan_follows           | table    |                           |                   |
 public | fans                  | table    |                           |                   |
 public | fans_fan_id_seq       | sequence |                           |                   |
(7 rows)
```

残りの権限を追加していきましょう。れらの権限は次のとおりです。

- ファンが自分のデータを確認し、アカウントを削除できるようにしたいと考えています。
- ファンがフォローしているアーティストを確認したり、アーティストをフォローしたりフォロー解除したりできるようにしたいと考えています。
- ファンがアーティストやアルバムを見ることができるようにしたいと考えています。
- アーティストが自分のデータを閲覧し、名前を編集できるようにしたいと考えています。
- アーティストがアルバムを作成、編集、削除できるようにしたいと考えています。

```sql
sample=> RESET ROLE;
RESET
sample=# GRANT SELECT, DELETE ON fans to fan;
GRANT
sample=# GRANT SELECT, INSERT, DELETE ON fan_follows TO fan;
GRANT
sample=# GRANT SELECT ON artists TO fan;
GRANT
sample=# GRANT SELECT ON albums TO fan;
GRANT
sample=# GRANT SELECT, UPDATE (name), DELETE ON artists to artist;
GRANT
sample=# GRANT SELECT, INSERT, UPDATE (title, released), DELETE ON albums to artist;
GRANT
```

サンプル データを追加して、権限が正しく機能するかどうかをテストしてみましょう。

```sql
sample=# INSERT INTO fans DEFAULT VALUES;
INSERT 0 1
sample=# INSERT INTO artists (name)
     VALUES ('DJ Okawari'), ('Steely Dan'), ('Missy Elliott');
INSERT 0 3
sample=# SET ROLE fan;
SET
sample=> INSERT INTO fan_follows (fan_id, artist_id)
     VALUES (1, 1), (1, 2);
INSERT 0 2
sample=> DELETE FROM fan_follows WHERE artist_id = 1;
DELETE 1
sample=> SELECT * FROM fans
     INNER JOIN fan_follows USING (fan_id)
     INNER JOIN artists USING (artist_id);
 artist_id | fan_id |    name
-----------+--------+------------
         2 |      1 | Steely Dan
(1 row)

sample=> UPDATE artists SET name = 'TWRP' WHERE artist_id = 2;
ERROR:  permission denied for table artists
sample=> SET ROLE artist;
SET
sample=> UPDATE artists SET name = 'TWRP' WHERE artist_id = 2;
UPDATE 1
sample=> INSERT INTO albums (artist_id, title, released)
     VALUES (3, 'Under Construction', '2002-11-12');
INSERT 0 1
sample=> UPDATE albums SET artist_id = 2;
ERROR:  permission denied for table albums
sample=> DELETE FROM artists;
DELETE 3
```

承認にロールと GRANT のみを使用してマルチユーザーアプリケーションを構築すると、ユーザーは互いのデータを削除したり、互いを削除したりできるようになります。ユーザーが自分のデータのみを読み取りおよび変更できるように制限するには、別のメカニズムが必要です。そのメカニズムは、行レベル セキュリティ (RLS) ポリシーです。

### ROW LEVEL SECURITY

前準備として songs テーブルを追加

```Sql
sample=# CREATE TABLE songs (
    song_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    album_id INTEGER NOT NULL REFERENCES albums(album_id) ON DELETE CASCADE,
    title TEXT NOT NULL
);
CREATE TABLE
sample=# GRANT SELECT ON songs TO fan;
GRANT
sample=# GRANT SELECT, INSERT, UPDATE (title), DELETE ON songs TO artist;
GRANT
```

テーブルで行レベルのセキュリティを有効にしてみましょう。

```sql
sample=# INSERT INTO artists (name)
     VALUES ('Tupper Ware Remix Party'), ('Steely Dan'), ('Missy Elliott');
INSERT 0 3
sample=# SET ROLE artist;
SET
sample=> SELECT * FROM artists;
 artist_id |          name
-----------+-------------------------
         4 | Tupper Ware Remix Party
         5 | Steely Dan
         6 | Missy Elliott
(3 rows)

sample=> RESET ROLE;
RESET
sample=# ALTER TABLE artists ENABLE ROW LEVEL SECURITY;
ALTER TABLE
sample=# SET ROLE artist;
SET
sample=> SELECT * FROM artists;
 artist_id | name
-----------+------
(0 rows)
```

```sql
sample=> RESET ROLE;
RESET
sample=# CREATE POLICY testing ON artists
    USING (true);
CREATE POLICY
sample=# SET ROLE artist;
SET
sample=> SELECT * FROM artists;
 artist_id |          name
-----------+-------------------------
         4 | Tupper Ware Remix Party
         5 | Steely Dan
         6 | Missy Elliott
(3 rows)

sample=> RESET ROLE;
RESET
sample=# ALTER POLICY testing ON artists
    USING (name = 'Steely Dan');
ALTER POLICY
sample=# SET ROLE artist;
SET
sample=> SELECT * FROM artists;
 artist_id |    name
-----------+------------
         5 | Steely Dan
(1 row)
```

### クエリユーザーに基づくポリシー

アーティストが自分の名前を変更できるようにし、他のアーティストの名前を変更できないようにします。

```sql
sample=# CREATE ROLE "artist:4" LOGIN;
GRANT artist TO "artist:4";
CREATE ROLE
GRANT ROLE

sample=# DROP POLICY testing ON artists;
DROP POLICY

sample=# CREATE POLICY viewable_by_all ON artists
    FOR SELECT
    USING (true);

CREATE POLICY

sample=# CREATE POLICY update_self ON artists
    FOR UPDATE
    TO artist
    USING (artist_id = substr(current_user, 8)::int);
CREATE POLICY
sample=# SET ROLE "artist:4";
SET

sample=# SET ROLE "artist:4";
SET
sample=> UPDATE artists SET name = 'TWRP';
UPDATE 1
sample=> SELECT * FROM artists;
 artist_id |     name
-----------+---------------
         5 | Steely Dan
         6 | Missy Elliott
         4 | TWRP
(3 rows)

sample=> UPDATE artists SET name = 'Ella Fitzgerald' WHERE name = 'Steely Dan';
UPDATE 0
```

### テーブルにまたがるポリシー

```sql
sample=# ALTER TABLE albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE
sample=# ALTER TABLE songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE
sample=# CREATE POLICY viewable_by_all ON albums
    FOR SELECT
    USING (true);
CREATE POLICY
sample=# CREATE POLICY viewable_by_all ON songs
    FOR SELECT
    USING (true);
CREATE POLICY

sample=# CREATE POLICY affect_own_albums ON albums
    FOR ALL
    TO artist
    USING (artist_id = substr(current_user, 8)::int);
CREATE POLICY
sample=# CREATE POLICY affect_own_songs ON songs
    FOR ALL
    TO artist
    USING (
        EXISTS (
            SELECT 1 FROM albums
            WHERE albums.album_id = songs.album_id
            AND albums.artist_id = substr(current_user, 8)::int
        )
    );
CREATE POLICY

sample=# INSERT INTO albums (artist_id, title, released)
    VALUES (6, 'Under Construction', '2002-11-12');
INSERT 0 1


sample=# SET ROLE "artist:4";
SET
sample=> INSERT INTO albums (artist_id, title, released)
    VALUES (1, 'Return to Wherever', '2019-07-11');
ERROR:  new row violates row-level security policy for table "albums"
sample=> INSERT INTO albums (artist_id, title, released)
    VALUES (4, 'Return to Wherever', '2019-07-11');
INSERT 0 1
sample=> INSERT INTO songs (album_id, title)
    VALUES (5, 'Hidden Potential');
INSERT 0 1

sample=> INSERT INTO albums (artist_id, title, released)
    VALUES (5, 'Pretzel Logic', '1974-02-20');
ERROR:  new row violates row-level security policy for table "albums"

sample=> INSERT INTO songs (album_id, title)
    VALUES (4, 'Work It');
ERROR:  new row violates row-level security policy for table "songs"
```

### 複数のポリシーの相互作用

RLS ポリシーの動作に関するもう 1 つの重要な側面は、複数のポリシーを組み合わせる方法です。ポリシーは主に 2 つの方法で相互作用します。

```sql
sample=>  RESET ROLE;
RESET
sample=# DROP POLICY viewable_by_all ON albums;
DROP POLICY
sample=# CREATE POLICY viewable_by_all ON albums
    FOR SELECT
    USING (true);
CREATE POLICY
sample=# CREATE POLICY hide_unreleased_from_fans ON albums
    AS RESTRICTIVE
    FOR SELECT
    TO fan
    USING (released <= now());
CREATE POLICY
sample=# CREATE POLICY hide_unreleased_from_other_artists ON albums
    AS RESTRICTIVE
    FOR SELECT
    TO artist
     USING (released <= now() or (artist_id = substr(current_user, 8)::int));
CREATE POLICY
```

異なる役割 (ファンとアーティスト) を対象とする PERMISSIVE ポリシーと RESTRICTIVE ポリシーを組み合わせることで、今後リリースされるアルバムを所有アーティストのみに公開できるようになりました。

このロジックを表現するより良い方法は、次のように PERMISSIVE ポリシーのみを使用することです。

```sql
sample=# DROP POLICY viewable_by_all ON albums;
DROP POLICY
sample=# DROP POLICY hide_unreleased_from_fans ON albums;
DROP POLICY
sample=# DROP POLICY hide_unreleased_from_other_artists ON albums;
DROP POLICY
sample=# CREATE POLICY viewable_by_all ON albums
    FOR SELECT
    USING (released <= now());
CREATE POLICY

sample=# DROP POLICY affect_own_albums ON albums;
DROP POLICY
sample=# CREATE POLICY affect_own_albums ON albums
    -- FOR ALL
    TO artist
    USING (artist_id = substr(current_user, 8)::int);
CREATE POLICY
```

複数のポリシーが相互作用するもう 1 つの方法は、ポリシーの USING 式が、独自のポリシーを持つ別のテーブルをクエリする場合です。サンプル アプリでは、アルバム テーブルのポリシーを使用して、そのアルバム内の曲を表示するかどうかを決定できます。

```sql
sample=# DROP POLICY viewable_by_all ON songs;
DROP POLICY
sample=# CREATE POLICY viewable_by_all ON songs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM albums
            WHERE albums.album_id = songs.album_id
        )
    );
CREATE POLICY
```

最後に、新しいポリシーをテストして、適切な役割/グループが将来のリリース日とその曲を含むアルバムを表示できる (または表示できない) ことを確認しましょう。

```sql
sample=# SET ROLE "artist:4";
SET
sample=> SELECT * FROM albums;
 album_id | artist_id |       title        |  released
----------+-----------+--------------------+------------
        3 |         6 | Under Construction | 2002-11-12
        5 |         4 | Return to Wherever | 2019-07-11
(2 rows)

sample=> SELECT * FROM songs;
 song_id | album_id |      title
---------+----------+------------------
       1 |        5 | Hidden Potential
(1 row)

sample=> SET ROLE fan;
SET
sample=> SELECT * FROM albums;
 album_id | artist_id |       title        |  released
----------+-----------+--------------------+------------
        3 |         6 | Under Construction | 2002-11-12
        5 |         4 | Return to Wherever | 2019-07-11
(2 rows)

sample=> SELECT * FROM songs;
 song_id | album_id |      title
---------+----------+------------------
       1 |        5 | Hidden Potential
(1 row)

```
