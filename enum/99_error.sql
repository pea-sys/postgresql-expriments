DO $$
DECLARE wk_setting text;
 BEGIN
  --識別子の最大長を取得
  SELECT setting INTO wk_setting FROM pg_settings where name = 'max_identifier_length'; 
  Select REPEAT('1',CAST(COALESCE(wk_setting,'0') AS INTEGER)) INTO wk_setting;
  raise WARNING '%', wk_setting;
  ALTER TYPE drink_size ADD VALUE IF NOT EXISTS wk_setting;
END$$;