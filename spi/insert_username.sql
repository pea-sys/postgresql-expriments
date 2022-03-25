sample=# create extension insert_username;
CREATE EXTENSION

CREATE TABLE username_test (name text,username text not null);

sample=# CREATE TRIGGER insert_usernames BEFORE INSERT OR UPDATE ON username_test
sample-#  FOR EACH ROW
sample-#  EXECUTE PROCEDURE insert_username (username);
CREATE TRIGGER

sample=# CREATE TRIGGER insert_usernames BEFORE INSERT OR UPDATE ON username_test
sample-#  FOR EACH ROW
sample-#  EXECUTE PROCEDURE insert_username (username);
CREATE TRIGGER
sample=# INSERT INTO username_test VALUES ('nothing');
INSERT 0 1
sample=# INSERT INTO username_test VALUES ('null', null);
INSERT 0 1
sample=# INSERT INTO username_test VALUES ('empty string', '');
INSERT 0 1
sample=# INSERT INTO username_test VALUES ('space', ' ');
INSERT 0 1
sample=# INSERT INTO username_test VALUES ('tab', '');
INSERT 0 1
sample=# INSERT INTO username_test VALUES ('name', 'name');
INSERT 0 1
sample=# SELECT * FROM username_test;
     name     | username
--------------+----------
 nothing      | postgres
 null         | postgres
 empty string | postgres
 space        | postgres
 tab          | postgres
 name         | postgres
(6 行)