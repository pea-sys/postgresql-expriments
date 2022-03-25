sample=# CREATE SEQUENCE next_id START -2 MINVALUE -2;
CREATE SEQUENCE

sample=# CREATE TABLE ids (id int4,idesc text);
CREATE TABLE

sample=# create extension autoinc;
CREATE EXTENSION

sample=# CREATE TRIGGER ids_nextid
sample-# BEFORE INSERT OR UPDATE ON ids
sample-# FOR EACH ROW
sample-# EXECUTE PROCEDURE autoinc (id, next_id);
CREATE TRIGGER

sample=# INSERT INTO ids VALUES (0, 'first (-2 ?)');
INSERT 0 1
sample=# INSERT INTO ids VALUES (null, 'second (-1 ?)');
INSERT 0 1
sample=# INSERT INTO ids(idesc) VALUES ('third (1 ?!)');
INSERT 0 1

sample=# SELECT * FROM ids;
 id |     idesc
----+---------------
 -2 | first (-2 ?)
 -1 | second (-1 ?)
  1 | third (1 ?!)
(3 行)

sample=# UPDATE ids SET id = null, idesc = 'first: -2 --> 2'
sample-# WHERE idesc = 'first (-2 ?)';
UPDATE 1
sample=# UPDATE ids SET id = 0, idesc = 'second: -1 --> 3'
sample-# WHERE id = -1;
UPDATE 1
sample=# UPDATE ids SET id = 4, idesc = 'third: 1 --> 4'
sample-# WHERE id = 1;
UPDATE 1
sample=# SELECT * FROM ids;
 id |      idesc
----+------------------
  2 | first: -2 --> 2
  3 | second: -1 --> 3
  4 | third: 1 --> 4
(3 行)


sample=# SELECT 'Wasn''t it 4 ?' as nextval, nextval ('next_id') as value;
    nextval    | value
---------------+-------
 Wasn't it 4 ? |     4
(1 行)


sample=# insert into ids (idesc) select textcat (idesc, '. Copy.') from ids;
INSERT 0 3
sample=# SELECT * FROM ids;
 id |          idesc
----+-------------------------
  2 | first: -2 --> 2
  3 | second: -1 --> 3
  4 | third: 1 --> 4
  5 | first: -2 --> 2. Copy.
  6 | second: -1 --> 3. Copy.
  7 | third: 1 --> 4. Copy.
(6 行)

sample=# drop extension autoinc cascade;
NOTICE:  削除はテーブルidsのトリガーids_nextidへ伝播します
DROP EXTENSION