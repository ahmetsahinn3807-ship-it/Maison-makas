-- 22. adım: randevular tablosu canlı yayında mı?
\set ON_ERROR_STOP 1
set client_min_messages = notice;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'randevular'
  ) then raise exception 'TEST HATASI: randevular yayında değil'; end if;
  if (select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'randevular') <> 1
  then raise exception 'TEST HATASI: tablo iki kez eklendi'; end if;
  raise notice 'GEÇTİ: randevular canlı yayında (bir kez)';
end $$;

do $$ begin raise notice 'TÜM TESTLER BİTTİ'; end $$;
