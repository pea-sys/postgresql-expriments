create or replace function scalar_return_ex2(target text) returns text AS $$
declare
	result constant text := 'Hello' || scalar_return_ex2.target;
begin
	return result;
end;
$$ language plpgsql;