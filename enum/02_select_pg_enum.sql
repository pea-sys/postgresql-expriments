SELECT * from pg_enum where enumtypid = (SELECT oid from pg_type where typname='drink_size');
