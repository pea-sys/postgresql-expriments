sample=# --Column ID of table A is primary key:

sample=# CREATE TABLE A ( ID int4 not null);
CREATE TABLE
sample=# CREATE UNIQUE INDEX AI ON A (ID);
CREATE INDEX
--Columns REFB of table B and REFC of C are foreign keys referencing ID of A:

sample=# CREATE TABLE B ( REFB int4);
CREATE TABLE
sample=# CREATE INDEX BI ON B (REFB);
CREATE INDEX
sample=# CREATE TABLE C ( REFC int4);
CREATE TABLE
sample=# CREATE INDEX CI ON C (REFC);
CREATE INDEX

sample=# --Trigger for table A:
sample=# create extension refint;
CREATE EXTENSION

sample=# CREATE TRIGGER AT BEFORE DELETE OR UPDATE ON A FOR EACH ROW
sample-# EXECUTE PROCEDURE
sample-# check_foreign_key (2, 'cascade', 'ID', 'B', 'REFB', 'C', 'REFC');
CREATE TRIGGER  

sample=# --Trigger for table B:

sample=# CREATE TRIGGER BT BEFORE INSERT OR UPDATE ON B FOR EACH ROW
sample-# EXECUTE PROCEDURE
sample-# check_primary_key ('REFB', 'A', 'ID');
CREATE TRIGGER

sample=# --Trigger for table C:

sample=# CREATE TRIGGER CT BEFORE INSERT OR UPDATE ON C FOR EACH ROW 
sample=# EXECUTE PROCEDURE 
sample=# check_primary_key ('REFC', 'A', 'ID');

sample=# INSERT INTO A VALUES (10);
INSERT 0 1
sample=# INSERT INTO A VALUES (20);
INSERT 0 1
sample=# INSERT INTO A VALUES (30);
INSERT 0 1
sample=# INSERT INTO A VALUES (40);
INSERT 0 1
sample=# INSERT INTO A VALUES (50);
INSERT 0 1
sample=# INSERT INTO B VALUES (1);-- invalid reference
ERROR:  there is no attribute "REFB" in relation "b"
sample=# INSERT INTO B VALUES (10);
ERROR:  there is no attribute "REFB" in relation "b"
sample=# INSERT INTO B VALUES (30);
ERROR:  there is no attribute "REFB" in relation "b"
sample=# INSERT INTO B VALUES (30);
ERROR:  there is no attribute "REFB" in relation "b"
sample=# INSERT INTO C VALUES (11);-- invalid reference
ERROR:  there is no attribute "REFC" in relation "c"
sample=# INSERT INTO C VALUES (20);
ERROR:  there is no attribute "REFC" in relation "c"
sample=# INSERT INTO C VALUES (20);
ERROR:  there is no attribute "REFC" in relation "c"


sample=# drop extension refint cascade;
NOTICE:  削除は他の3個のオブジェクトに対しても行われます
DETAIL:  削除はテーブルbのトリガーbtへ伝播します
削除はテーブルcのトリガーctへ伝播します
削除はテーブルaのトリガーatへ伝播します
DROP EXTENSION

-- 最も古い拡張機能のせいかサンプル通り動かない。外部キーを使えば良いので確認省略
-- https://github.com/postgres/postgres/blob/master/contrib/spi/refint.example