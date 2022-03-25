sample=# create extension moddatetime;
CREATE EXTENSION
sample=# CREATE TABLE mdt (id int4, idesc text, moddate timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL);
CREATE TABLE

sample=# CREATE TRIGGER mdt_moddatetime
sample-#  BEFORE UPDATE ON mdt
sample-#  FOR EACH ROW
sample-#  EXECUTE PROCEDURE moddatetime (moddate);
CREATE TRIGGER

sample=# INSERT INTO mdt VALUES (1, 'first');
INSERT 0 1
sample=# INSERT INTO mdt VALUES (2, 'second');
INSERT 0 1
sample=# INSERT INTO mdt VALUES (3, 'third');
INSERT 0 1
sample=# SELECT * FROM mdt;
 id | idesc  |          moddate
----+--------+----------------------------
  1 | first  | 2022-03-26 08:19:45.003656
  2 | second | 2022-03-26 08:19:45.015839
  3 | third  | 2022-03-26 08:19:46.69171
(3 行)

sample=# UPDATE mdt SET id = 4
sample-# WHERE id = 1;
UPDATE 1
sample=# UPDATE mdt SET id = 5
sample-# WHERE id = 2;
UPDATE 1
sample=# UPDATE mdt SET id = 6
sample-# WHERE id = 3;
UPDATE 1
sample=#
sample=# SELECT * FROM mdt;
 id | idesc  |          moddate
----+--------+----------------------------
  4 | first  | 2022-03-26 08:20:10.040022
  5 | second | 2022-03-26 08:20:10.054209
  6 | third  | 2022-03-26 08:20:10.069386
(3 行)