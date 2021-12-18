DROP TABLE IF EXISTS t1;

CREATE TABLE IF NOT EXISTS t1 (
  name       text,
  value      numeric(3),
  PRIMARY KEY ( name )
);

INSERT INTO t1 VALUES ('tea', 100);
INSERT INTO t1 VALUES ('water', 500);
INSERT INTO t1 VALUES ('X', 50);
INSERT INTO t1 VALUES ('Y', 100);