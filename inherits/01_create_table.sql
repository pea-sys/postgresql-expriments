CREATE TABLE IF NOT EXISTS drink_tbl (
  name       text,
  size 	     text,
  PRIMARY KEY ( name )
);

CREATE TABLE IF NOT EXISTS alcohol_tbl (
  alcohol_percentage real
) INHERITS (drink_tbl);

INSERT INTO drink_tbl VALUES ('tea', 'S');
INSERT INTO drink_tbl VALUES ('water', 'L');
INSERT INTO drink_tbl VALUES ('X', 'L');
INSERT INTO alcohol_tbl VALUES ('beer', 'S', 3);
INSERT INTO alcohol_tbl VALUES ('X', 'M', 5);
INSERT INTO alcohol_tbl VALUES ('X', 'M', 5);