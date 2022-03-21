ALTER ROLE test WITH PASSWORD 'test';
--ERROR:  password is too short
ALTER ROLE test123456 WITH PASSWORD 'test123456';
--ERROR:  password must not contain user name
ALTER ROLE test123456 WITH PASSWORD 'aaaaaaaaaaaaaaaa';
--ERROR:  password must contain both letters and nonletters