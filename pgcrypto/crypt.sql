create table accounts(user_id text, password text);
CREATE TABLE
insert into accounts(user_id) values('user01');
INSERT 0 1
update accounts set password = crypt('new password',gen_salt('md5'));
UPDATE 1
select (password = crypt('password',password)) as pswmatch from accounts where user_id = 'user01';
 pswmatch
----------
 f
(1 行)
select (password = crypt('new password',password)) as pswmatch from accounts where user_id = 'user01';
 pswmatch
----------
 t
(1 行)