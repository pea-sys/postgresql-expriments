sample=# create extension pg_trgm;
CREATE EXTENSION
sample=# select similarity('12345','54321');
 similarity
------------
          0
(1 行)


sample=# select similarity('he','she');
 similarity
------------
 0.16666667
(1 行)

sample=# select word_similarity('He looks good','She is beautiful');
 word_similarity
-----------------
     0.071428575
(1 行)

sample=# select 'aiueo' % 'kakikukeko';
 ?column?
----------
 f
(1 行)


sample=# select 'aiueo' % 'kaiueo';
 ?column?
----------
 t
(1 行)

sample=# select 'aiueo' <% 'kaiueo';
 ?column?
----------
 t
(1 行)


sample=# select 'aiueo' <% 'kakikukeko';
 ?column?
----------
 f
(1 行)

sample=# select 'aiueo' %> 'kaiueo';
 ?column?
----------
 f
(1 行)


sample=# select 'kaiueo' %> 'kaiueo';
 ?column?
----------
 t
(1 行)

sample=# select 'kaiueo' <<% 'kaiueo';
 ?column?
----------
 t
(1 行)


sample=# select 'kaiueo' <<% 'kakikukeko';
 ?column?
----------
 f
(1 行)

sample=# select 'kaiueo' %>> 'kakikukeko';
 ?column?
----------
 f
(1 行)


sample=# select 'kaiueo' %>> 'kaiueo';
 ?column?
----------
 t
(1 行)

sample=# select 'kaiueo' <-> 'kakikukeko';
 ?column?
----------
    0.875

sample=# select 'kaiueo' <<-> 'aiueo';
 ?column?
-----------
 0.4285714