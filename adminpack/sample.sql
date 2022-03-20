do $$
declare
 tmp_file_path constant text := 'C:\Program Files\PostgreSQL\14\data\log\adminpack.tmp';
 commit_file_path constant text := 'C:\Program Files\PostgreSQL\14\data\log\adminpack.txt';
 current_log text;
begin
    select pg_catalog.pg_logdir_ls() into current_log order by pg_logdir_ls desc limit 1;
	raise info '%',current_log;
	perform pg_catalog.pg_file_write(tmp_file_path,now()::text,false);
	perform pg_catalog.pg_file_write(tmp_file_path,now()::text,true);
	perform pg_catalog.pg_file_sync(tmp_file_path);
	perform pg_catalog.pg_file_rename ( tmp_file_path, commit_file_path);
	perform pg_catalog.pg_file_unlink(tmp_file_path);
end $$;

