SELECT t1.id, t1.name, ss.value FROM t1 ,
   (SELECT value FROM t2 WHERE t2.name = t1.name)ss;

/*
ERROR:  テーブル"t1"用のFROM句に対する不正な参照
LINE 2:    (SELECT value FROM t2 WHERE t2.name = t1.name)ss;
                                                 ^
HINT:  テーブル"t1"の項目がありますが、問い合わせのこの部分からは参照できません。"
*/