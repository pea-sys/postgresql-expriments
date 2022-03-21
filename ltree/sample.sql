select '1.2'::ltree @> '1.2.3'::ltree;
 ?column?
----------
 t
select '1.2.3'::ltree @> '1.2'::ltree;
 ?column?
----------
 f
 select '1.2'::ltree <@ '1.2.3'::ltree;
 ?column?
----------
 f
select '1.2.3'::ltree <@ '1.2'::ltree;
 ?column?
----------
 t
 select '1.2.3'::ltree ~ '*.2.*'::lquery;
 ?column?
----------
 t
select '1.2.3'::ltree ~ '*{3}'::lquery;
 ?column?
----------
 t
 select array['*{3}'::lquery,'*{2}'] ? '1.2.3'::ltree;
 ?column?
----------
 t
 select '1.a'::ltree ? array['*{3}'::lquery,'*.A@'];
 ?column?
----------
 t
 select 'aiueo.a'::ltree @ 'AIUEO*@ & !Transportation';
 ?column?
----------
 t
 select '1.2.3.4.5'::ltree || '6.7.8.9.10'::ltree;
       ?column?
----------------------
 1.2.3.4.5.6.7.8.9.10
 select '1.2.3.4.5'::ltree <@ array['6.7.8.9.10'::ltree,'1.2.3'];
 ?column?
----------
 t
 select '1.2.3.4.5'::ltree @> array['6.7.8.9.10'::ltree,'1.2.3'];
 ?column?
----------
 f
 select '1.2.3.*' ~ array['6.7.8.9.10'::ltree,'1.2.3'];
 ?column?
----------
 t
 select array['1.2.3.4.*'::lquery,'AbC@'] ? array['6.7.8.9.10'::ltree,'1.2.3','abc'];
 ?column?
----------
 t
 select '8 & 9 & (10|11)'::ltxtquery @ array['6.7.8.9.10'::ltree,'1.2.3','abc'];
 ?column?
----------
 t
 select array['6'::ltree,'1.2.3','abc'] ?@> '6.7.8.9.10'::ltree;
 ?column?
----------
6
 select array['6.7.8.9.10.11'::ltree,'6.7.8.9.10.13'] ?<@ '6.7.8.9.10'::ltree;
   ?column?
---------------
 6.7.8.9.10.11
 select array['4.5.6'::ltree, '1.2.3'] ?~ '*.3'::lquery;
 ?column?
----------
 1.2.3
 select array['4.5.6'::ltree, '1.2.3'] ?@ '5 & 6'::ltxtquery;
 ?column?
----------
 4.5.6
 select subltree('Top.Child1.Child2.Child3', 1, 3);
   subltree
---------------
 Child1.Child2
 select subpath('Top.Child1.Child2', 0, 2);
  subpath
------------
 Top.Child1
 select subpath('Top.Child1.Child2', 1);
    subpath
---------------
 Child1.Child2
select nlevel('Top.Child1.Child2');
 nlevel
--------
3
select index('0.1.2.3.5.4.5.6.8.5.6.8', '5.6');
 index
-------
6
select index('0.1.2.3.5.4.5.6.8.5.6.8', '5.6', -4);
 index
-------
9
select text2ltree ('Top.Child1.Child2'::text);
    text2ltree
-------------------
 Top.Child1.Child2
select ltree2text ('Top.Child1'::ltree);
 ltree2text
------------
 Top.Child1
 select lca('1.2.3', '1.2.3.4.5.6.8.9','1.2.3.9');
 lca
-----
1.2
select lca(array['1.2.3'::ltree,'1.2.3.4','1.2.3.4.5']);
 lca
-----
1.2
