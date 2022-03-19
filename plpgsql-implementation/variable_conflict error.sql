--ERROR:  column reference "id" is ambiguous
--LINE 2:           WHERE users.id = id
drop table if exists users;
create table users (id int, comment text, last_modified timestamp);
CREATE OR REPLACE FUNCTION stamp_user(id int, comment text) RETURNS void AS $$
    #variable_conflict error
    DECLARE
        curtime timestamp := now();
    BEGIN
        UPDATE users SET last_modified = curtime, comment = comment
          WHERE users.id = id;
    END;
$$ LANGUAGE plpgsql;

insert into users (id) values (1);
select stamp_user(1, '40y');