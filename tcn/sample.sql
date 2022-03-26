sample=# CREATE EXTENSION tcn;
CREATE EXTENSION
sample=# create table tcndata(
sample(#      a int not null,
sample(#      b date not null,
sample(#      c text,
sample(#      primary key (a, b)
sample(# );
CREATE TABLE
sample=# create trigger tcndata_tcn_trigger
sample-#    after insert or update or delete on tcndata
sample-#    for each row execute function triggered_change_notification();
CREATE TRIGGER
sample=# listen tcn;
LISTEN
sample=# insert into tcndata values (1, date '2012-12-22', 'one'),
sample-#                             (1, date '2012-12-23', 'another'),
sample-#                             (2, date '2012-12-23', 'two');
INSERT 0 3
PID 2564のサーバープロセスから、ペイロード""tcndata",I,"a"='1',"b"='2012-12-22'"を持つ非同期通知"tcn"を受信しました。
PID 2564のサーバープロセスから、ペイロード""tcndata",I,"a"='1',"b"='2012-12-23'"を持つ非同期通知"tcn"を受信しました。
PID 2564のサーバープロセスから、ペイロード""tcndata",I,"a"='2',"b"='2012-12-23'"を持つ非同期通知"tcn"を受信しました。
sample=# update tcndata set c = 'uno' where a = 1;
UPDATE 2
PID 2564のサーバープロセスから、ペイロード""tcndata",U,"a"='1',"b"='2012-12-22'"を持つ非同期通知"tcn"を受信しました。
PID 2564のサーバープロセスから、ペイロード""tcndata",U,"a"='1',"b"='2012-12-23'"を持つ非同期通知"tcn"を受信しました。
sample=# delete from tcndata where a = 1 and b = date '2012-12-22';
DELETE 1
PID 2564のサーバープロセスから、ペイロード""tcndata",D,"a"='1',"b"='2012-12-22'"を持つ非同期通知"tcn"を受信しました。
sample=# unlisten tcn;
UNLISTEN