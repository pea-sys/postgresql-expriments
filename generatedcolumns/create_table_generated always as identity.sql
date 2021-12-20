drop table if exists t1;
create table t1(
  original_id integer generated always as identity, 
  name varchar(100),
  created timestamp default current_timestamp,
  primary key(original_id)
);

insert into t1(name, created)
select
  format('テスト商品%s', i), 
  clock_timestamp()
from
  generate_series(1, 3) as i
;

select * from t1;