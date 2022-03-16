create type complex_type AS (t text, c int);

create or replace function scalar_return_complex_ex1() returns complex_type AS $$
declare
	result complex_type;
begin
	result.t := 'Hello';
	result.c = 10;
	return result;
end;
$$ language plpgsql;
