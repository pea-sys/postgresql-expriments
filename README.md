# postgresql_expriments
PostgreSQLの実験用リポジトリ  
環境変数設定方法:PostgreSQLのインストールフォルダ直下の「pg_env.bat」を実行  
基本的にはオフィシャルページの中から仕事に関係しそうな部分を全てハンズオンで試しています  
https://www.postgresql.jp/document/13/html/  

■飛ばした項目  
・第12章 全文検索  
・第16章 ソースコードからインストール  
・第17章 Windowsにおけるソースコードからのインストール   
・第20章 クライアント認証  
・第31章 実行時コンパイル(JIT)  
・第32章 リグレッションテスト  
・第33章 libpq — C ライブラリ  
・第34章 ラージオブジェクト
・第35章 ECPG — C言語による埋め込みSQL    
・第37章 SQLの拡張 
・第43章 PL/Tcl — Tcl手続き言語  
・第44章 PL/Perl — Perl手続き言語  
・第45章 PL/Python — Python手続き言語  
・第46章 サーバプログラミングインタフェース
・VI. リファレンス
※その他、重複する内容や内部実装のカスタム方法等を飛ばしています


[実験環境]
OS:Windows10
DB:PostgreSQL14  

[設定]
postgresql.conf  
lc_message = 'en_US' --ログ文字化け対策