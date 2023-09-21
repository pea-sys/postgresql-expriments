# pg_stat_io ビューの確認

postgresql 16 で追加された pg_stat_io ビューを確認する。

| 列の種類       | 型                       | 説明                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| -------------- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| backend_type   | text                     | バックエンドの種類（バックグラウンドワーカー、autovacuum ワーカーなど）。詳細については pg_stat_activity を参照してください。いくつかの backend_types は I/O 操作の統計情報を蓄積せず、ビューに含まれません。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| object         | text                     | I/O 操作のターゲット オブジェクト。可能な値は次のとおりです。 _ relation: 永久的な関係 <br> _ temp relation：一時的な関係。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| context        | text                     | I/O 操作のコンテキスト。可能な値は次のとおりです。<br>_ normal: I/O 操作のタイプのデフォルト。たとえば、デフォルトでは、リレーション データは共有バッファに読み込まれ、共有バッファから書き出されます。したがって、共有バッファへのリレーション データの読み取りと共有バッファからのリレーション データの書き込みは、 context normal で追跡されます。<br> _ vacuum: 永続的な関係をバキュームおよび分析する際に、共有バッファーの外で実行される I/O 操作。一時テーブルのバキュームは、他の一時テーブル IO 操作と同じローカル バッファ プールを使用し、context normal で追跡されます。<br>bulkread: 共有バッファの外部で実行される特定の大規模な読み取り I/O 操作 (大きなテーブルの順次スキャンなど)。<br>bulkwrite: 共有バッファの外部で実行される特定の大規模な書き込み I/O 操作（COPY など）。 |
| reads          | bigint                   | 読み取り操作の数。それぞれのサイズは op_bytes で指定されます。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| read_time      | double precision         | 読み取り操作に費やした時間 (ミリ秒単位) ( track_io_timing が有効な場合、それ以外の場合はゼロ)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| writes         | bigint                   | 書き込み操作の数。それぞれのサイズは op_bytes で指定されます。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| write_time     | double precision         | 書き込み操作に費やされた時間 (ミリ秒単位) ( track_io_timing が有効な場合、それ以外の場合はゼロ)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| writebacks     | bigint                   | プロセスがカーネルに永続ストレージへの書き込みを要求した op_bytes サイズの単位数。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| writeback_time | double precision         | ライトバック操作に費やされた時間 (ミリ秒単位) ( track_io_timing が有効な場合、それ以外の場合はゼロ)。これには、書き込み要求のキューに費やされる時間と、場合によってはダーティ データの書き込みに費やされる時間が含まれます。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| extends        | bigint                   | リレーション拡張操作の数。それぞれのサイズは op_bytes で指定されます。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| extend_time    | double precision         | 拡張操作に費やした時間 (ミリ秒単位) ( track_io_timing が有効な場合、それ以外の場合はゼロ)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| op_bytes       | bigint                   | I/O の読み取り、書き込み、拡張の単位あたりのバイト数。関係データの読み取り、書き込み、拡張は、ビルド時のパラメータ BLCKSZ に由来する block_size 単位で行われ、デフォルトでは 8192 である。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| hits           | bigint                   | 共有バッファー内で目的のブロックが見つかった回数。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| evictions      | bigint                   | ブロックを別の用途に使用できるようにするために、ブロックが共有バッファまたはローカルバッファから書き出された回数。通常のコンテキストでは、これはブロックがバッファから追い出されて別のブロックに置き換えられた回数を数える。bulkwrite、bulkread、vacuum コンテキストでは、バルク I/O 操作で使用するために、サイズ制限のある別のリングバッファに共有バッファを追加するために、共有バッファからブロックが追い出された回数をカウントする。                                                                                                                                                                                                                                                                                                                                                         |
| reuses         | bigint                   | バルクリード、バルクライト、バキュームコンテキストの I/O 操作の一部として、共有バッファ以外のサイズ制限リングバッファ内の既存バッファが再利用された回数。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| fsyncs         | bigint                   | fsync コールの回数。これらは通常のコンテキストでのみ追跡される。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| fsync_time     | double precision         | fsync 操作に費やされた時間（ミリ秒単位）（track_io_timing が有効な場合、それ以外はゼロ                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| stats_reset    | timestamp with time zone | これらの統計が最後にリセットされた時刻。                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |

## 準備

```sql
PS C:\Users\user> psql -U postgres -p 5432 -d postgres -c "CREATE DATABASE sample TEMPLATE = template0 ENCODING = 'UTF-8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';"
CREATE DATABASE
PS C:\Users\user> psql -U postgres -p 5432 -d sample
ユーザー postgres のパスワード:
psql (16.0)
"help"でヘルプを表示します。
PS C:\Users\user> psql -U postgres -d sample
sample=# set track_io_timing = on;
SET
sample=# \pset format html
出力形式は html です。


PS C:\Users\user> pgbench -U postgres --initialize --scale=10 sample
Password:
dropping old tables...
NOTICE:  繝・・繝悶Ν"pgbench_accounts"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_branches"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_history"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
NOTICE:  繝・・繝悶Ν"pgbench_tellers"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
creating tables...
generating data (client-side)...
1000000 of 1000000 tuples (100%) done (elapsed 2.18 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 5.43 s (drop tables 0.02 s, create tables 0.03 s, client-side generate 3.32 s, vacuum 0.52 s, primary keys 1.54 s).
PS C:\Users\user> psql -U postgres -d sample
ユーザー postgres のパスワード:
psql (16.0)
"help"でヘルプを表示します。
sample=# select * from pg_stat_io where reads <> 0 or writes <> 0;
```

<table border="1">
  <tr>
    <th align="center">backend_type</th>
    <th align="center">object</th>
    <th align="center">context</th>
    <th align="center">reads</th>
    <th align="center">read_time</th>
    <th align="center">writes</th>
    <th align="center">write_time</th>
    <th align="center">writebacks</th>
    <th align="center">writeback_time</th>
    <th align="center">extends</th>
    <th align="center">extend_time</th>
    <th align="center">op_bytes</th>
    <th align="center">hits</th>
    <th align="center">evictions</th>
    <th align="center">reuses</th>
    <th align="center">fsyncs</th>
    <th align="center">fsync_time</th>
    <th align="center">stats_reset</th>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">6949</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">2544</td>
    <td align="right">0</td>
    <td align="right">6773</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 16:44:43.45368+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkwrite</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">16452</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">16135</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 16:44:43.45368+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">42</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">20</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">10225</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 16:44:43.45368+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">vacuum</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">2111</td>
    <td align="right">0</td>
    <td align="right">14372</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 16:44:43.45368+09</td>
  </tr>
  <tr valign="top">
    <td align="left">background worker</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">7604</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">1243</td>
    <td align="right">0</td>
    <td align="right">7540</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 16:44:43.45368+09</td>
  </tr>
  <tr valign="top">
    <td align="left">checkpointer</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">1694</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">302</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 16:44:43.45368+09</td>
  </tr>
</table>
<p>(6 行)<br />
</p>

io 統計情報をリセット  
pg_stat_reset_shared()ではリセットされないので注意。

```sql
sample=# select pg_stat_reset_shared('io');

sample=# select * from pg_stat_io where reads <> 0 or writes <> 0;
```

<table border="1">
  <tr>
    <th align="center">backend_type</th>
    <th align="center">object</th>
    <th align="center">context</th>
    <th align="center">reads</th>
    <th align="center">read_time</th>
    <th align="center">writes</th>
    <th align="center">write_time</th>
    <th align="center">writebacks</th>
    <th align="center">writeback_time</th>
    <th align="center">extends</th>
    <th align="center">extend_time</th>
    <th align="center">op_bytes</th>
    <th align="center">hits</th>
    <th align="center">evictions</th>
    <th align="center">reuses</th>
    <th align="center">fsyncs</th>
    <th align="center">fsync_time</th>
    <th align="center">stats_reset</th>
  </tr>
</table>
<p>(0 行)<br />
</p>

- pgbench でデータ作成

```sql
PS C:\Users\user> pgbench -U postgres --initialize --scale=10 sample
Password:
dropping old tables...
NOTICE:  繝・・繝悶Ν"pgbench_accounts"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_branches"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺
NOTICE:  繝・・繝悶Ν"pgbench_history"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
NOTICE:  繝・・繝悶Ν"pgbench_tellers"縺ｯ蟄伜惠縺励∪縺帙ｓ縲√せ繧ｭ繝・・縺励∪縺・
creating tables...
generating data (client-side)...
1000000 of 1000000 tuples (100%) done (elapsed 2.14 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 5.28 s (drop tables 0.01 s, create tables 0.02 s, client-side generate 3.39 s, vacuum 0.49 s, primary keys 1.37 s).
```

- io 統計情報の確認

```sql
PS C:\Users\user> psql -U postgres -d sample
ユーザー postgres のパスワード:
psql (16.0)
"help"でヘルプを表示します。
sample=# select * from pg_stat_io where reads <> 0 or writes <> 0;
```

<table border="1">
  <tr>
    <th align="center">backend_type</th>
    <th align="center">object</th>
    <th align="center">context</th>
    <th align="center">reads</th>
    <th align="center">read_time</th>
    <th align="center">writes</th>
    <th align="center">write_time</th>
    <th align="center">writebacks</th>
    <th align="center">writeback_time</th>
    <th align="center">extends</th>
    <th align="center">extend_time</th>
    <th align="center">op_bytes</th>
    <th align="center">hits</th>
    <th align="center">evictions</th>
    <th align="center">reuses</th>
    <th align="center">fsyncs</th>
    <th align="center">fsync_time</th>
    <th align="center">stats_reset</th>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">6696</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">654</td>
    <td align="right">0</td>
    <td align="right">6664</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkwrite</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">16452</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">16135</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">vacuum</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">2111</td>
    <td align="right">0</td>
    <td align="right">14372</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">background worker</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">7676</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">1368</td>
    <td align="right">0</td>
    <td align="right">7612</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">checkpointer</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">962</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">316</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
</table>
<p>(5 行)<br />
</p>

- ANALYZE 実施  
  テーブルが４つあるので relation-normal の reads が４になってます（多分)

```sql
sample=# analyze;
<p>ANALYZE</p>
sample=# select * from pg_stat_io where reads <> 0 or writes <> 0;
```

<table border="1">
  <tr>
    <th align="center">backend_type</th>
    <th align="center">object</th>
    <th align="center">context</th>
    <th align="center">reads</th>
    <th align="center">read_time</th>
    <th align="center">writes</th>
    <th align="center">write_time</th>
    <th align="center">writebacks</th>
    <th align="center">writeback_time</th>
    <th align="center">extends</th>
    <th align="center">extend_time</th>
    <th align="center">op_bytes</th>
    <th align="center">hits</th>
    <th align="center">evictions</th>
    <th align="center">reuses</th>
    <th align="center">fsyncs</th>
    <th align="center">fsync_time</th>
    <th align="center">stats_reset</th>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">6696</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">654</td>
    <td align="right">0</td>
    <td align="right">6664</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkwrite</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">16452</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">16135</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">4</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">37</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">10985</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">vacuum</td>
    <td align="right">28680</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">4603</td>
    <td align="right">0</td>
    <td align="right">28616</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">background worker</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">7676</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">1368</td>
    <td align="right">0</td>
    <td align="right">7612</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">checkpointer</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">962</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">316</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
</table>
<p>(6 行)<br />
</p>

- checkpoint の実行  
  checkpointer の書き込み回数と fsync 回数が増えています。こうやってみると CHECKPOINT のディスク書き込み量が多く、負荷が大きい操作であることが分かります。

```sql
sample=# checkpoint;
<p>CHECKPOINT</p>
sample=# select * from pg_stat_io where reads <> 0 or writes <> 0;
```

<table border="1">
  <tr>
    <th align="center">backend_type</th>
    <th align="center">object</th>
    <th align="center">context</th>
    <th align="center">reads</th>
    <th align="center">read_time</th>
    <th align="center">writes</th>
    <th align="center">write_time</th>
    <th align="center">writebacks</th>
    <th align="center">writeback_time</th>
    <th align="center">extends</th>
    <th align="center">extend_time</th>
    <th align="center">op_bytes</th>
    <th align="center">hits</th>
    <th align="center">evictions</th>
    <th align="center">reuses</th>
    <th align="center">fsyncs</th>
    <th align="center">fsync_time</th>
    <th align="center">stats_reset</th>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">6696</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">654</td>
    <td align="right">0</td>
    <td align="right">6664</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkwrite</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">16452</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">16135</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">6</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">37</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">14912</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">vacuum</td>
    <td align="right">28680</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">4603</td>
    <td align="right">0</td>
    <td align="right">28616</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">background worker</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">7676</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">1368</td>
    <td align="right">0</td>
    <td align="right">7612</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">checkpointer</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">3060</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">350</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
</table>
<p>(6 行)<br />
</p>

- 2 回程、pgbench_accounts テーブルをテーブルスキャンします。clientbackend の relation の normal の読み取りバイトが増えています。テーブルサイズ分増えていないのは、キャッシュヒット分？

```sql
sample=# select * from pg_stat_io where reads <> 0 or writes <> 0;
```

<table border="1">
  <tr>
    <th align="center">backend_type</th>
    <th align="center">object</th>
    <th align="center">context</th>
    <th align="center">reads</th>
    <th align="center">read_time</th>
    <th align="center">writes</th>
    <th align="center">write_time</th>
    <th align="center">writebacks</th>
    <th align="center">writeback_time</th>
    <th align="center">extends</th>
    <th align="center">extend_time</th>
    <th align="center">op_bytes</th>
    <th align="center">hits</th>
    <th align="center">evictions</th>
    <th align="center">reuses</th>
    <th align="center">fsyncs</th>
    <th align="center">fsync_time</th>
    <th align="center">stats_reset</th>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">20940</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">2804</td>
    <td align="right">0</td>
    <td align="right">20876</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkwrite</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">16452</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">16135</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">2742</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">37</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">16347</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">vacuum</td>
    <td align="right">28680</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">4603</td>
    <td align="right">0</td>
    <td align="right">28616</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">background worker</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">7676</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">1368</td>
    <td align="right">0</td>
    <td align="right">7612</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">checkpointer</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">3060</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">350</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
</table>
<p>(6 行)<br />
</p>

```
sample=# SELECT
sample-# relname as table_name,
sample-# reltuples as row_num,
sample-# (relpages * 8192) as byte_size
sample-# FROM
sample-# pg_class
sample-# WHERE
sample-# relname = 'pgbench_accounts';

```

<table border="1">
  <tr>
    <th align="center">table_name</th>
    <th align="center">row_num</th>
    <th align="center">byte_size</th>
  </tr>
  <tr valign="top">
    <td align="left">pgbench_accounts</td>
    <td align="right">1e+06</td>
    <td align="right">134299648</td>
  </tr>
</table>
<p>(1 行)<br />
</p>

ちなみに時間を測定するには postgresql.conf の設定値を変更する必要がある

postgresql.conf

```
shared_preload_libraries = 'pg_stat_statements'
```

read_time に時間が記録されています

```sql
sample=# set track_io_timing = on;
sample=# select * from pg_stat_io where reads <> 0 or writes <> 0;
```

<table border="1">
  <tr>
    <th align="center">backend_type</th>
    <th align="center">object</th>
    <th align="center">context</th>
    <th align="center">reads</th>
    <th align="center">read_time</th>
    <th align="center">writes</th>
    <th align="center">write_time</th>
    <th align="center">writebacks</th>
    <th align="center">writeback_time</th>
    <th align="center">extends</th>
    <th align="center">extend_time</th>
    <th align="center">op_bytes</th>
    <th align="center">hits</th>
    <th align="center">evictions</th>
    <th align="center">reuses</th>
    <th align="center">fsyncs</th>
    <th align="center">fsync_time</th>
    <th align="center">stats_reset</th>
  </tr>
  <tr valign="top">
    <td align="left">autovacuum launcher</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">1</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">591</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">autovacuum worker</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">145</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">22313</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">67908</td>
    <td align="right">322.565</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">5018</td>
    <td align="right">0</td>
    <td align="right">67748</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">bulkwrite</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">16452</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">16135</td>
    <td align="right">0</td>
    <td align="right">14404</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">2862</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">37</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">18820</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">client backend</td>
    <td align="left">relation</td>
    <td align="left">vacuum</td>
    <td align="right">28680</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">8192</td>
    <td align="right">4603</td>
    <td align="right">0</td>
    <td align="right">28616</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">background worker</td>
    <td align="left">relation</td>
    <td align="left">bulkread</td>
    <td align="right">7676</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">1368</td>
    <td align="right">0</td>
    <td align="right">7612</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
  <tr valign="top">
    <td align="left">checkpointer</td>
    <td align="left">relation</td>
    <td align="left">normal</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">3060</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">0</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">8192</td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">&nbsp; </td>
    <td align="right">350</td>
    <td align="right">0</td>
    <td align="left">2023-09-21 17:22:41.42417+09</td>
  </tr>
</table>
<p>(8 行)<br />
</p>
ディスク IO がパフォーマンスに与える影響は大きいので、これから有効な利用法を検討していきたいです。
