select
    pg_par.relname parent_table_name
   ,pg_chi.relname child_table_name
from
    pg_inherits inh
        inner join pg_class pg_par on inh.inhparent = pg_par.oid
        inner join pg_class pg_chi on inh.inhrelid  = pg_chi.oid
order by
    parent_table_name
   ,child_table_name
;