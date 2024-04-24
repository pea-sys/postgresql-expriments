# インデックス作成オプション

次のブログのトレースです。  
複数のインデックス使用時のパフォーマンスについて記載しています。

https://kmoppel.github.io/2022-12-09-the-bountiful-world-of-postgres-indexing-options/

任意のクエリを動かす pgbench の動かし方は勉強になりました。  
また、古いバージョンではカバーリングインデックスが効果的な可能性もあるとの示唆も興味深いものでした。

実験をトレースするのは非常に簡単で、こちらのスクリプトを使用するだけです

https://gist.github.com/kmoppel/9ba1f938140448dc1919a21c215196b1#file-full_index_test_10m_rows-sh

```sql
postgres@masami-L:~$ SQL=$(cat << "EOF"
\set int1000 random(0, 999)
\set int100 random(0, 99)
SELECT count(*) FROM test_table WHERE int1000 = :int1000 AND int100 = :int100;
EOF
)

echo -e "\n\n*** Composite ***\n"
psql -Xc "CREATE INDEX IF NOT EXISTS test_table_composite ON test_table (int1000, int100);"
echo ""
echo "$SQL" | pgbench -n -f- -T $DURATION -c $CLIENTS -j $JOBS
psql -Xc "DROP INDEX IF EXISTS test_table_composite;"

echo -e "\n\n*** Merge / bitmaps scan ***\n"
psql -Xc "CREATE INDEX IF NOT EXISTS test_table_int1000 ON test_table (int1000);"
psql -Xc "CREATE INDEX IF NOT EXISTS test_table_int100 ON test_table (int100);"

echo ""
echo "$SQL" | pgbench -n -f- -T $DURATION -c $CLIENTS -j $JOBS
psql -Xc "DROP INDEX IF EXISTS test_table_int1000;"
psql -Xc "DROP INDEX IF EXISTS test_table_int100;"

echo -e "\n\n*** Covering index ***\n"
psql -Xc "CREATE INDEX IF NOT EXISTS test_table_covering ON test_table (int1000) INCLUDE (int100);"
echo ""
echo "$SQL" | pgbench -n -f- -T $DURATION -c $CLIENTS -j $JOBS
psql -Xc "DROP INDEX IF EXISTS test_table_covering;"

echo -e "\n\n*** Hash ***\n"
psql -Xc "CREATE INDEX IF NOT EXISTS test_table_hash_int1000 ON test_table USING hash (int1000);"
psql -Xc "CREATE INDEX IF NOT EXISTS test_table_hash_int100 ON test_table USING hash(int100);"
echo ""
#psql -Xc "DROP INDEX IF EXISTS test_table_hash_int100;""$JOBS


*** Composite ***

CREATE INDEX

pgbench (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
transaction type: -
scaling factor: 1
query mode: simple
number of clients: 2
number of threads: 1
duration: 1800 s
number of transactions actually processed: 29713610
latency average = 0.121 ms
initial connection time = 6.156 ms
tps = 16507.616402 (without initial connection time)
DROP INDEX


*** Merge / bitmaps scan ***

CREATE INDEX
CREATE INDEX

pgbench (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
transaction type: -
scaling factor: 1
query mode: simple
number of clients: 2
number of threads: 1
duration: 1800 s
number of transactions actually processed: 1426322
latency average = 2.524 ms
initial connection time = 5.858 ms
tps = 792.402766 (without initial connection time)
DROP INDEX
DROP INDEX


*** Covering index ***

CREATE INDEX

pgbench (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
transaction type: -
scaling factor: 1
query mode: simple
number of clients: 2
number of threads: 1
duration: 1800 s
number of transactions actually processed: 14574199
latency average = 0.247 ms
initial connection time = 5.795 ms
tps = 8096.802439 (without initial connection time)
DROP INDEX


*** Hash ***

CREATE INDEX
CREATE INDEX

pgbench (14.10 (Ubuntu 14.10-0ubuntu0.22.04.1))
transaction type: -
scaling factor: 1
query mode: simple
number of clients: 2
number of threads: 1
duration: 1800 s
number of transactions actually processed: 1334541
latency average = 2.698 ms
initial connection time = 5.773 ms
tps = 741.413178 (without initial connection time)
postgres@masami-L:~$
```

| インデックス | 実行時間 | サイズ          |
| ------------ | -------- | --------------- |
| 複合         | 0.121ms  | 10,264          |
| マージ       | 2.542ms  | 7,274+7,004     |
| カバーリング | 0.247ms  | 31,563          |
| ハッシュ     | 0.2698ms | 49,070 + 46,137 |
