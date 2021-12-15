CREATE TABLE IF NOT EXISTS t1 (
  name       text,
  value      numeric(3),
  PRIMARY KEY ( name )
);

CREATE TABLE IF NOT EXISTS t2 (
  name       text,
  value      numeric(3),
  PRIMARY KEY ( name )
);

INSERT INTO t1 VALUES ('tea', 100);
INSERT INTO t1 VALUES ('water', 500);
INSERT INTO t1 VALUES ('X', 50);

INSERT INTO t2 VALUES ('tea', 10);
INSERT INTO t2 VALUES ('water', 50);
INSERT INTO t1 VALUES ('Y', 100);
