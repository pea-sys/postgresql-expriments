create or replace function scalar_return_ex1(int) returns integer AS $$
begin
	return $1 + 1;
end;
$$ language plpgsql;