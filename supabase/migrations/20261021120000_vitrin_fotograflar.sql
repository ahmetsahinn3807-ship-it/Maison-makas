-- ============================================================================
-- Maison Makas · Vitrin ve fotoğraflar (19. adım)
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- 17–18. adımdaki koddan sonra çalıştırılır. Yanlışlıkla iki kez çalışırsa zararı yoktur.
--
--   profil kovası  müşterinin profil ve kapak fotoğrafı: yalnız kendisi yükler ve siler
--   salon kovası   salonun kapak, logo ve galeri fotoğrafları: yalnız salon sahibi yükler ve siler
--   kesfet         salon kartları için kapak odağı, logo ve vitrin ayarlarıyla
--
-- Fotoğraflar herkese açık adresle gösterilir; adresler tahmin edilemez (kullanıcı ya da salon
-- kimliği + zaman damgası). Dosya silmek yalnız Storage API ile yapılır (uygulama yapar).
-- ============================================================================

begin;

-- 1. Kovalar: herkese açık okunur, dosya başına en çok 6 MB, yalnız resim.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('profil', 'profil', true, 6291456, array['image/jpeg', 'image/png', 'image/webp']),
  ('salon', 'salon', true, 6291456, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 2. Klasör sahipliği. Yol düzeni: profil/<kullanıcı kimliği>/…, salon/<salon kimliği>/…
create or replace function public.profil_klasorum_mu(p_nesne text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null
     and split_part(p_nesne, '/', 1) = (select auth.uid())::text;
$$;

create or replace function public.salon_klasorum_mu(p_nesne text)
returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.salonlar s
    where s.id::text = split_part(p_nesne, '/', 1)
      and s.sahip_id = (select auth.uid())
  );
$$;

revoke execute on function public.profil_klasorum_mu(text) from public, anon;
revoke execute on function public.salon_klasorum_mu(text) from public, anon;
grant execute on function public.profil_klasorum_mu(text) to authenticated;
grant execute on function public.salon_klasorum_mu(text) to authenticated;

-- 3. Depolama kuralları. Okuma herkese açık adresle olur; buradaki "görür" kuralı
--    uygulamanın kendi dosyalarını listeleyip silebilmesi içindir.
drop policy if exists "profil fotoğrafı sahibi görür" on storage.objects;
drop policy if exists "profil fotoğrafı sahibi yükler" on storage.objects;
drop policy if exists "profil fotoğrafı sahibi değiştirir" on storage.objects;
drop policy if exists "profil fotoğrafı sahibi siler" on storage.objects;
drop policy if exists "salon fotoğrafı sahibi görür" on storage.objects;
drop policy if exists "salon fotoğrafı sahibi yükler" on storage.objects;
drop policy if exists "salon fotoğrafı sahibi değiştirir" on storage.objects;
drop policy if exists "salon fotoğrafı sahibi siler" on storage.objects;

create policy "profil fotoğrafı sahibi görür" on storage.objects for select to authenticated
  using (bucket_id = 'profil' and public.profil_klasorum_mu(name));
create policy "profil fotoğrafı sahibi yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'profil' and public.profil_klasorum_mu(name));
create policy "profil fotoğrafı sahibi değiştirir" on storage.objects for update to authenticated
  using (bucket_id = 'profil' and public.profil_klasorum_mu(name))
  with check (bucket_id = 'profil' and public.profil_klasorum_mu(name));
create policy "profil fotoğrafı sahibi siler" on storage.objects for delete to authenticated
  using (bucket_id = 'profil' and public.profil_klasorum_mu(name));

create policy "salon fotoğrafı sahibi görür" on storage.objects for select to authenticated
  using (bucket_id = 'salon' and public.salon_klasorum_mu(name));
create policy "salon fotoğrafı sahibi yükler" on storage.objects for insert to authenticated
  with check (bucket_id = 'salon' and public.salon_klasorum_mu(name));
create policy "salon fotoğrafı sahibi değiştirir" on storage.objects for update to authenticated
  using (bucket_id = 'salon' and public.salon_klasorum_mu(name))
  with check (bucket_id = 'salon' and public.salon_klasorum_mu(name));
create policy "salon fotoğrafı sahibi siler" on storage.objects for delete to authenticated
  using (bucket_id = 'salon' and public.salon_klasorum_mu(name));

-- 4. Keşfet: salon kartı kapak fotoğrafını odağıyla, logoyu ve vitrin ayarlarını (tema, filtre) alır.
drop function if exists public.kesfet(text);
create function public.kesfet(p_arama text default null)
returns table (
  id uuid,
  kisa_ad text,
  ad text,
  ilce text,
  sehir text,
  logo_url text,
  kapak_url text,
  kapak_odak_x real,
  kapak_odak_y real,
  vitrin jsonb,
  dogrulandi boolean,
  ortalama numeric,
  yorum_adet integer
)
language sql stable security invoker set search_path = '' as $$
  select s.id, s.kisa_ad, s.ad, s.ilce, s.sehir, s.logo_url, s.kapak_url,
         s.kapak_odak_x, s.kapak_odak_y, s.vitrin, s.dogrulandi,
         p.ortalama, coalesce(p.adet, 0)
  from public.salonlar s
  left join public.salon_puanlari p on p.salon_id = s.id
  where s.yayinda
    and (
      nullif(btrim(p_arama), '') is null
      or s.ad ilike '%' || btrim(p_arama) || '%'
      or s.ilce ilike '%' || btrim(p_arama) || '%'
      or s.sehir ilike '%' || btrim(p_arama) || '%'
    )
  order by s.dogrulandi desc, p.ortalama desc nulls last, s.ad
  limit 50;
$$;
grant execute on function public.kesfet(text) to anon, authenticated;

commit;
