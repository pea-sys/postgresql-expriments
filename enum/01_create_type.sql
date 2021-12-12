DROP TYPE IF EXISTS drink_size;
DROP TYPE IF EXISTS shirts_size;

CREATE TYPE drink_size AS ENUM ('S', 'M', 'L');
CREATE TYPE shirts_size AS ENUM ('S', 'M', 'L', 'XL');

ALTER TYPE drink_size ADD VALUE 'LS';
ALTER TYPE drink_size RENAME VALUE 'LS' TO 'LL';
