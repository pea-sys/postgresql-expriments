sample=# CREATE EXTENSION "uuid-ossp";

sample=# SELECT uuid_nil();
               uuid_nil
--------------------------------------
 00000000-0000-0000-0000-000000000000
(1 行)


sample=# SELECT uuid_ns_dns();
             uuid_ns_dns
--------------------------------------
 6ba7b810-9dad-11d1-80b4-00c04fd430c8
(1 行)


sample=# SELECT uuid_ns_url();
             uuid_ns_url
--------------------------------------
 6ba7b811-9dad-11d1-80b4-00c04fd430c8
(1 行)


sample=# SELECT uuid_ns_oid();
             uuid_ns_oid
--------------------------------------
 6ba7b812-9dad-11d1-80b4-00c04fd430c8
(1 行)


sample=# SELECT uuid_ns_x500();
             uuid_ns_x500
--------------------------------------
 6ba7b814-9dad-11d1-80b4-00c04fd430c8
(1 行)

sample=# -- some quick and dirty field extraction functions
sample=#
sample=# -- this is actually timestamp concatenated with clock sequence, per RFC 4122
sample=# CREATE FUNCTION uuid_timestamp_bits(uuid) RETURNS varbit AS
sample-# $$ SELECT ('x' || substr($1::text, 15, 4) || substr($1::text, 10, 4) ||
sample$#            substr($1::text, 1, 8) || substr($1::text, 20, 4))::bit(80)
sample$#           & x'0FFFFFFFFFFFFFFF3FFF' $$
sample-# LANGUAGE SQL STRICT IMMUTABLE;
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION uuid_version_bits(uuid) RETURNS varbit AS
sample-# $$ SELECT ('x' || substr($1::text, 15, 2))::bit(8) & '11110000' $$
sample-# LANGUAGE SQL STRICT IMMUTABLE;
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION uuid_reserved_bits(uuid) RETURNS varbit AS
sample-# $$ SELECT ('x' || substr($1::text, 20, 2))::bit(8) & '11000000' $$
sample-# LANGUAGE SQL STRICT IMMUTABLE;
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION uuid_multicast_bit(uuid) RETURNS bool AS
sample-# $$ SELECT (('x' || substr($1::text, 25, 2))::bit(8) & '00000001') != '00000000' $$
sample-# LANGUAGE SQL STRICT IMMUTABLE;
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION uuid_local_admin_bit(uuid) RETURNS bool AS
sample-# $$ SELECT (('x' || substr($1::text, 25, 2))::bit(8) & '00000010') != '00000000' $$
sample-# LANGUAGE SQL STRICT IMMUTABLE;
CREATE FUNCTION
sample=#
sample=# CREATE FUNCTION uuid_node(uuid) RETURNS text AS
sample-# $$ SELECT substr($1::text, 25) $$
sample-# LANGUAGE SQL STRICT IMMUTABLE;
CREATE FUNCTION
sample=#
sample=# -- Ideally, the multicast bit would never be set in V1 output, but the
sample=# -- UUID library may fall back to MC if it can't get the system MAC address.
sample=# -- Also, the local-admin bit might be set (if so, we're probably inside a VM).
sample=# -- So we can't test either bit here.
sample=# SELECT uuid_version_bits(uuid_generate_v1()),
sample-#        uuid_reserved_bits(uuid_generate_v1());
 uuid_version_bits | uuid_reserved_bits
-------------------+--------------------
 00010000          | 10000000
(1 行)


sample=#
sample=# -- Although RFC 4122 only requires the multicast bit to be set in V1MC style
sample=# -- UUIDs, our implementation always sets the local-admin bit as well.
sample=# SELECT uuid_version_bits(uuid_generate_v1mc()),
sample-#        uuid_reserved_bits(uuid_generate_v1mc()),
sample-#        uuid_multicast_bit(uuid_generate_v1mc()),
sample-#        uuid_local_admin_bit(uuid_generate_v1mc());
 uuid_version_bits | uuid_reserved_bits | uuid_multicast_bit | uuid_local_admin_bit
-------------------+--------------------+--------------------+----------------------
 00010000          | 10000000           | t                  | t
(1 行)


sample=#
sample=# -- timestamp+clock sequence should be monotonic increasing in v1
sample=# SELECT uuid_timestamp_bits(uuid_generate_v1()) < uuid_timestamp_bits(uuid_generate_v1());
 ?column?
----------
 t
(1 行)


sample=# SELECT uuid_timestamp_bits(uuid_generate_v1mc()) < uuid_timestamp_bits(uuid_generate_v1mc());
 ?column?
----------
 t
(1 行)


sample=#
sample=# -- Ideally, the node value is stable in V1 addresses, but OSSP UUID
sample=# -- falls back to V1MC behavior if it can't get the system MAC address.
sample=# SELECT CASE WHEN uuid_multicast_bit(uuid_generate_v1()) AND
sample-#                  uuid_local_admin_bit(uuid_generate_v1()) THEN
sample-#          true -- punt, no test
sample-#        ELSE
sample-#          uuid_node(uuid_generate_v1()) = uuid_node(uuid_generate_v1())
sample-#        END;
 case
------
 t
(1 行)


sample=#
sample=# -- In any case, V1MC node addresses should be random.
sample=# SELECT uuid_node(uuid_generate_v1()) <> uuid_node(uuid_generate_v1mc());
 ?column?
----------
 t
(1 行)


sample=# SELECT uuid_node(uuid_generate_v1mc()) <> uuid_node(uuid_generate_v1mc());
 ?column?
----------
 t
(1 行)


sample=#
sample=# SELECT uuid_generate_v3(uuid_ns_dns(), 'www.widgets.com');
           uuid_generate_v3
--------------------------------------
 3d813cbb-47fb-32ba-91df-831e1593ac29
(1 行)


sample=# SELECT uuid_generate_v5(uuid_ns_dns(), 'www.widgets.com');
           uuid_generate_v5
--------------------------------------
 21f7f8de-8051-5b89-8680-0195ef798b6a
(1 行)


sample=#
sample=# SELECT uuid_version_bits(uuid_generate_v4()),
sample-#        uuid_reserved_bits(uuid_generate_v4());
 uuid_version_bits | uuid_reserved_bits
-------------------+--------------------
 01000000          | 10000000
(1 行)


sample=#
sample=# SELECT uuid_generate_v4() <> uuid_generate_v4();
 ?column?
----------
 t