# postgresの継承の動作確認  
-- 実験環境:Postgresql 13.2  

■感想  
selectクエリを解釈してみると、親テーブルは、ビューとテーブルが合体したインターフェースを  
提供しているだけなのかなという感想。  
正直使いどころはかなり難しい。  
実務で使っても混乱を招く気がしました(DBの中身を知ろうとしない人も多い)。 
 
