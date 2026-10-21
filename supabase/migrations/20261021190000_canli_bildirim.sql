-- ============================================================================
-- Maison Makas · Anlık randevu bildirimleri (22. adım)
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- 21. adımdaki koddan sonra çalıştırılır. Yanlışlıkla iki kez çalışırsa zararı yoktur.
--
-- randevular tablosu Supabase Realtime yayınına eklenir: Makas Pro açıkken yeni randevu ve
-- iptal anında görünür; müşteri, salonun iptal ettiği randevudan haberdar olur.
-- Herkes yalnız görmeye yetkili olduğu satırların değişikliğini alır (satır güvenliği kuralları geçerlidir).
-- Hatırlatmalar sunucu gerektirmez; müşterinin telefonu kendisi zamanlar.
-- ============================================================================

begin;

do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'randevular'
  ) then
    alter publication supabase_realtime add table public.randevular;
  end if;
end;
$$;

commit;
