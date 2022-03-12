do
$$
declare
  l_rec record;
begin
  for l_rec in (select foreign_table_schema, foreign_table_name 
                from information_schema.foreign_tables) loop
     execute format('drop foreign table %I.%I', l_rec.foreign_table_schema, l_rec.foreign_table_name);
  end loop;
end;
$$;