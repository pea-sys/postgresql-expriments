# Streaming Replication

### ■ ストリーミングレプリケーションのリカバリー

同期スタンバイ サーバーに障害が発生し、ACK 応答を返すことができなくなった場合でも、プライマリ サーバーは永遠に応答を待ち続けます。

これが一過性のものなら PC 再起動したら直る可能性があります。
または、同期コミットを無効にして、設定リロードを行うことでフリーズ再発を回避できます。

```pwsh
synchronous_standby_names = ''
postgres> pg_ctl -D $PGDATA reload
```
