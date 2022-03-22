sample=# select pg_prewarm('actor', 'buffer','main');
 pg_prewarm
------------
          2
(1 行)

sample=# explain analyze table actor;
                                             QUERY PLAN
----------------------------------------------------------------------------------------------------
 Seq Scan on actor  (cost=0.00..4.00 rows=200 width=25) (actual time=0.026..0.041 rows=200 loops=1)
 Planning Time: 0.086 ms
 Execution Time: 0.065 ms
(3 行)

sample=# SELECT
sample-#     C.relname
sample-#     ,count(*) AS buffers
sample-# FROM
sample-#     pg_buffercache B
sample-# INNER JOIN pg_class C
sample-#     ON b.relfilenode = pg_relation_filenode(c.oid)
sample-#     AND
sample-#     b.reldatabase IN (
sample(#         0
sample(#         ,(
sample(#             SELECT oid
sample(#             FROM pg_database
sample(#             WHERE datname = current_database()
sample(#         )
sample(#     )
sample-# GROUP BY C.relname
sample-# ORDER BY 2 DESC
sample-# ;
                 relname                 | buffers
-----------------------------------------+---------
 pg_attribute                            |      31
 pg_class                                |      13
 pg_attribute_relid_attnum_index         |       9
 pg_proc                                 |       9
 pg_proc_oid_index                       |       8
 pg_amproc                               |       5
 pg_index                                |       5
 pg_amop                                 |       5
 pg_statistic                            |       4
 pg_proc_proname_args_nsp_index          |       4
 pg_amop_opr_fam_index                   |       4
 pg_class_oid_index                      |       4
 pg_type                                 |       4
 pg_statistic_relid_att_inh_index        |       4
 pg_operator_oid_index                   |       3
 pg_amop_fam_strat_index                 |       3
 pg_amproc_fam_proc_index                |       3
 pg_class_relname_nsp_index              |       3
 pg_type_typname_nsp_index               |       3
 pg_opclass                              |       3
 pg_operator_oprname_l_r_n_index         |       3
 pg_type_oid_index                       |       3
 pg_index_indrelid_index                 |       2
 pg_cast_source_target_index             |       2
 pg_conversion_default_index             |       2
 pg_operator                             |       2
 actor                                   |       2

-- autoprewarmを起動時に無効にして、後から手動で起動する方法は分からなかった
sample=# select autoprewarm_start_worker();
ERROR:  autoprewarm worker is already running under PID 9228
sample=# select autoprewarm_start_worker();
サーバーとの接続が予期せずクローズされました
        おそらく要求の処理前または処理中にサーバが異常終了
        したことを意味しています。
サーバーへの接続が失われました。リセットしています: 成功。
sample=# select autoprewarm_start_worker();
ERROR:  autoprewarm is disabled



sample=# select autoprewarm_dump_now();
 autoprewarm_dump_now
----------------------
                  262
(1 行)