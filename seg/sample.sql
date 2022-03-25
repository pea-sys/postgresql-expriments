sample=# select '1.9 .. 2.0'::seg << '2.5 ..2.6'::seg;
 ?column?
----------
 t
(1 行)


sample=# select '1.9 .. 2.8'::seg << '2.5 ..2.6'::seg;
 ?column?
----------
 f
(1 行)

sample=# select '2.6 .. 2.8'::seg >> '2.5 ..2.6'::seg;
 ?column?
----------
 f
(1 行)


sample=# select '2.61 .. 2.8'::seg >> '2.5 ..2.6'::seg;
 ?column?
----------
 t
(1 行)

sample=# select '1.9 .. 2.8'::seg &< '2.5 ..2.6'::seg;
 ?column?
----------
 f
(1 行)


sample=# select '1.9 .. 2.5'::seg &< '2.5 ..2.6'::seg;
 ?column?
----------
 t
(1 行)

sample=# select '1.9 .. 2.5'::seg &> '2.5 ..2.6'::seg;
 ?column?
----------
 f
(1 行)

sample=# select '2.9 .. 3.5'::seg &> '2.5 ..2.6'::seg;
 ?column?
----------
 t
(1 行)

sample=# select '2.9 .. 3.5'::seg && '2.5 ..2.6'::seg;
 ?column?
----------
 f
(1 行)


sample=# select '1.9 .. 3.5'::seg && '2.5 ..2.6'::seg;
 ?column?
----------
 t
(1 行)

sample=# select '2.9 .. 3.5'::seg @> '2.5 ..2.6'::seg;
 ?column?
----------
 f
(1 行)


sample=# select '2.1 .. 3.5'::seg @> '2.5 ..2.6'::seg;
 ?column?
----------
 t
(1 行)

sample=# select '2.6 .. 3.6'::seg <@ '2.5 ..2.6'::seg;
 ?column?
----------
 f
(1 行)


sample=# select '2.55 .. 2.56'::seg <@ '2.5 ..2.6'::seg;
 ?column?
----------
 t