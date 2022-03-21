create extension pgcrypto;
CREATE EXTENSION
select digest('password','md5');
               digest
------------------------------------
 \x5f4dcc3b5aa765d61d8327deb882cf99
(1 行)
select digest('password','sha1');
                   digest
--------------------------------------------
 \x5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8
(1 行)
select digest('password','sha224');
                           digest
------------------------------------------------------------
 \xd63dc919e201d7bc4c825630d2cf25fdc93d4b2f0d46706d29038d01
(1 行)
select digest('password','sha384');
                                               digest                                
----------------------------------------------------------------------------------------------------
 \xa8b64babd0aca91a59bdbb7761b421d4f2bb38280d3a75ba0f21f2bebc45583d446c598660c94ce680c47d19c30783a7
(1 行)
select digest('password','sha512');
                                                               digest                
------------------------------------------------------------------------------------------------------------------------------------
 \xb109f3bbbc244eb82441917ed06d618b9008dd09b3befd1b5e07394c706a8bb980b1d7785e5976ec049b46df5f1326af5a2ea6d103fd07c95385ffab0cacbc86
(1 行)

select hmac('password','key','sha512');
                                                                hmac                 
------------------------------------------------------------------------------------------------------------------------------------
 \x239b9209e9e19d2dd35e33af90b63e3e6c156436238393c7d2a58adb754fa7d727eba0517cff4b62074cd27523a42c56c067b8047b3bd9b09940e94fcea7f960
(1 行)



