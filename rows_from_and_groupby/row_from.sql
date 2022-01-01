SELECT * FROM ROWS FROM 
(
	generate_series(1, 3),
	generate_series(1, 4), 
	json_to_recordset('[{"a":40,"b":"foo"},{"a":"100","b":"bar"}]') AS (a INTEGER, b TEXT)
) AS x (p, q, r, s) ORDER BY p;