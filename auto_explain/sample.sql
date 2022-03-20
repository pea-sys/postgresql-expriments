/*  2022-03-20 16:34:39.198 JST [9788] LOG:  duration: 0.039 ms  plan:
	Query Text: LOAD 'auto_explain';
	SET auto_explain.log_analyze = true;
	SET auto_explain.log_min_duration = 0;
	SET auto_explain.log_wal = true;
	SET auto_explain.log_timing = true;
	SET auto_explain.log_triggers = true;
	SET auto_explain.log_verbose= true;
	SET auto_explain.log_settings = true;
	SET auto_explain.log_nested_statements = true;
	insert into actor (actor_id,first_name,last_name) values(-999,'first','last');

	Insert on public.actor  (cost=0.00..0.01 rows=0 width=0) (actual time=0.038..0.038 rows=0 loops=1)
	  WAL: records=3 bytes=207
	  ->  Result  (cost=0.00..0.01 rows=1 width=228) (actual time=0.003..0.003 rows=1 loops=1)
	        Output: '-999'::integer, 'first'::character varying(45), 'last'::character varying(45), now()
*/
LOAD 'auto_explain';
SET auto_explain.log_analyze = true;
SET auto_explain.log_min_duration = 0;
SET auto_explain.log_wal = true;
SET auto_explain.log_timing = true;
SET auto_explain.log_triggers = true;
SET auto_explain.log_verbose= true;
SET auto_explain.log_settings = true;
SET auto_explain.log_nested_statements = true;
insert into actor (actor_id,first_name,last_name) values(-999,'first','last');

