# マッチングパフォーマンス

次のリポジトリのトレースです  
少しクエリを削ってます

https://github.com/evanj/pg-benchmarks

各型ごとのマッチングパフォーマンスを測定します

各型の列を比較して、どの型が用途に適しているか判断する用途で使えます

### 実行環境

---

- PostgreSQL 16
- Windows10

---

## jsonb

|                              | inline Uncompressed | inline Compressed | toast Uncompressed | toast Compressed |
| ---------------------------- | ------------------- | ----------------- | ------------------ | ---------------- |
| data bytes                   | 2000                | 2001              | 2001               | 2761             |
| pg_column_size column bytes  | 2008                | 117               | 2005               | 2010             |
| pg_column_size table bytes   | 2032                | 141               | 2033               | 2038             |
| table pages                  | 250000              | 18182             | 6370               | 6370             |
| toast pages                  | 0                   | 0                 | 333334             | 333334           |
| pg_total_relation_size (MiB) | 1954                | 142               | 2698               | 2698             |
| --                           | --                  | --                | --                 | --               |
| count found first ->         | 560                 | 713               | 2799               | 7646             |
| count found last ->          | 541                 | 772               | 2774               | 7577             |
| count not found ->           | 442                 | 621               | 2691               | 7476             |

## json

|                              | inline Uncompressed | inline Compressed | toast Uncompressed | toast Compressed |
| ---------------------------- | ------------------- | ----------------- | ------------------ | ---------------- |
| data bytes                   | 2005                | 2004              | 2005               | 2893             |
| pg_column_size column bytes  | 2008                | 144               | 2005               | 2005             |
| pg_column_size table bytes   | 2032                | 168               | 2033               | 2033             |
| table pages                  | 250000              | 21277             | 6370               | 6370             |
| toast pages                  | 0                   | 0                 | 333334             | 333334           |
| pg_total_relation_size (MiB) | 1954                | 166               | 2698               | 2698             |
| --                           | --                  | --                | --                 | --               |
| count found first ->         | 2633                | 3085              | 6802               | 12558            |
| count found last ->          | 2679                | 3315              | 6829               | 12476            |
| count not found ->           | 2640                | 3121              | 6785               | 12683            |

## hstore

|                              | inline Uncompressed | inline Compressed | toast Uncompressed | toast Compressed |
| ---------------------------- | ------------------- | ----------------- | ------------------ | ---------------- |
| data bytes                   | 1942                | 1941              | 1945               | 2628             |
| pg_column_size column bytes  | 2008                | 200               | 2005               | 2006             |
| pg_column_size table bytes   | 2032                | 224               | 2033               | 2034             |
| table pages                  | 250000              | 28572             | 6370               | 6370             |
| toast pages                  | 0                   | 0                 | 333334             | 333334           |
| pg_total_relation_size (MiB) | 1954                | 223               | 2698               | 2698             |
| --                           | --                  | --                | --                 | --               |
| found                        | 872                 | 1373              | 4873               | 9481             |
| not found                    | 822                 | 1344              | 4824               | 9509             |
| count found                  | 875                 | 1371              | 4841               | 9502             |
| count not found              | 820                 | 1335              | 4778               | 9409             |

## bytea

|                                              | inline Uncompressed | inline Compressed | toast Uncompressed | toast Compressed |
| -------------------------------------------- | ------------------- | ----------------- | ------------------ | ---------------- |
| data bytes                                   | 2004                | 2005              | 2005               | 2766             |
| pg_column_size column bytes                  | 2008                | 44                | 2005               | 2005             |
| pg_column_size table bytes                   | 2032                | 68                | 2033               | 2033             |
| table pages                                  | 250000              | 9346              | 6370               | 6370             |
| toast pages                                  | 0                   | 0                 | 333334             | 333334           |
| pg_total_relation_size (MiB)                 | 1954                | 73                | 2698               | 2698             |
| --                                           | --                  | --                | --                 | --               |
| select v                                     | 705                 | 107               | 108                | 107              |
| select count(\*)                             | 721                 | 170               | 173                | 170              |
| select count(\*) where not null              | 765                 | 170               | 173                | 170              |
| select count(\*) where len > 100             | 762                 | 178               | 177                | 176              |
| select count(\*) where len > 10000           | 664                 | 80                | 80                 | 79               |
| select count(\*) where LIKE not match        | 2517                | 1495              | 177                | 12014            |
| select count(\*) where LIKE match at end     | 2450                | 1604              | 6448               | 11732            |
| select count(\*) where position not match    | 2632                | 1529              | 6473               | 12368            |
| select count(\*) where position match at end | 2554                | 1632              | 6566               | 12092            |

## text

|                                              | inline Uncompressed | inline Compressed | toast Uncompressed | toast Compressed |
| -------------------------------------------- | ------------------- | ----------------- | ------------------ | ---------------- |
| data bytes                                   | 2004                | 2005              | 2005               | 2766             |
| pg_column_size column bytes                  | 2008                | 44                | 2055               | 2005             |
| pg_column_size table bytes                   | 2032                | 68                | 2033               | 2033             |
| table pages                                  | 250000              | 9346              | 6370               | 6370             |
| toast pages                                  | 0                   | 0                 | 333334             | 333334           |
| pg_total_relation_size (MiB)                 | 1954                | 73                | 2698               | 2698             |
| --                                           | --                  | --                | --                 | --               |
| select v                                     | 708                 | 107               | 108                | 110              |
| select count(\*)                             | 735                 | 130               | 133                | 136              |
| select count(\*) where not null              | 768                 | 169               | 169                | 174              |
| select count(\*) where len > 100             | 791                 | 176               | 177                | 175              |
| select count(\*) where len > 10000           | 684                 | 80                | 81                 | 81               |
| select count(\*) where LIKE not match        | 4604                | 4257              | 8657               | 15680            |
| select count(\*) where LIKE match at end     | 4468                | 4252              | 8463               | 15143            |
| select count(\*) where position not match    | 20738               | 15131             | 19821              | 13237            |
| select count(\*) where position match at end | 21400               | 15630             | 20813              | 21571            |
