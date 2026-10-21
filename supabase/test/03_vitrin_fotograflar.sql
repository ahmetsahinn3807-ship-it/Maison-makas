-- 19. adım: depolama kuralları, galeri ve kesfet testleri (temiz veriyle).
\set ON_ERROR_STOP 1
\pset footer off
set client_min_messages = notice;

\set sahip  '''11111111-1111-1111-1111-111111111111'''
\set mA     '''33333333-3333-3333-3333-333333333333'''
\set mB     '''44444444-4444-4444-4444-444444444444'''
\set salon  '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''

insert into auth.users (id, email, raw_user_meta_data) values
  (:sahip, 'sahip@test', '{"ad_soyad": "Ahmet Şahin"}'),
  (:mA, 'a@test', '{"ad_soyad": "Ali Kaya"}'),
  (:mB, 'b@test', '{"ad_soyad": "Burak"}');

do $$ begin
  if (select count(*) from storage.buckets where id in ('profil', 'salon') and public) <> 2
  then raise exception 'TEST HATASI: kovalar'; end if;
  raise notice 'GEÇTİ: profil ve salon kovaları herkese açık';
end $$;

reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda, ilce, sehir)
values (:salon, :sahip, 'uim-riva', 'UİM Riva Şube', true, 'Riva', 'İstanbul');

-- Salon sahibi kendi klasörüne yükler, başka salonun klasörüne yükleyemez.
insert into storage.objects (bucket_id, name) values
  ('salon', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/kapak-1.jpg'),
  ('salon', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/galeri/g1.jpg');
do $$ begin
  insert into storage.objects (bucket_id, name) values ('salon', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb/kapak.jpg');
  raise exception 'TEST HATASI: başka salona yüklendi';
exception when insufficient_privilege then raise notice 'GEÇTİ: sahip yalnız kendi salon klasörüne yükler';
end $$;
do $$ begin
  insert into storage.objects (bucket_id, name) values ('salon', 'kapak.jpg');
  raise exception 'TEST HATASI: klasörsüz yükleme';
exception when insufficient_privilege then raise notice 'GEÇTİ: klasörsüz yol reddedildi';
end $$;

update public.salonlar
set kapak_url = 'https://ornek/salon/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/kapak-1.jpg',
    kapak_odak_x = 0.3, kapak_odak_y = 0.7,
    logo_url = 'https://ornek/salon/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/logo-1.jpg',
    vitrin = '{"tema": "ivoire", "vurgu": 1, "filtre": "sicak"}'
where id = :salon;
insert into public.galeri (salon_id, url, kategori, herkese_acik, aciklama)
values (:salon, 'https://ornek/salon/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/galeri/g1.jpg', 'sac', true, 'Usta Mert · Fade');
-- Vitrin Stüdyosu kaydı "update … returning id" ile doğrular: sahipte bir satır döner.
do $$ declare n int; begin
  with g as (
    update public.salonlar set vitrin = vitrin where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning id
  ) select count(*) into n from g;
  if n <> 1 then raise exception 'TEST HATASI: sahibin güncellemesi satır döndürmedi (%)', n; end if;
  raise notice 'GEÇTİ: sahibin vitrin kaydı satırı döndürüyor';
end $$;

-- Müşteri A: kendi profil klasörü evet, başkasınınki ve salonunki hayır.
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
insert into storage.objects (bucket_id, name) values ('profil', '33333333-3333-3333-3333-333333333333/avatar-1.jpg');
do $$ begin
  insert into storage.objects (bucket_id, name) values ('profil', '44444444-4444-4444-4444-444444444444/avatar.jpg');
  raise exception 'TEST HATASI: başkasının profil klasörüne yüklendi';
exception when insufficient_privilege then raise notice 'GEÇTİ: müşteri yalnız kendi profil klasörüne yükler';
end $$;
do $$ begin
  insert into storage.objects (bucket_id, name) values ('salon', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa/kapak-2.jpg');
  raise exception 'TEST HATASI: müşteri salon klasörüne yükledi';
exception when insufficient_privilege then raise notice 'GEÇTİ: müşteri salon klasörüne yükleyemez';
end $$;
do $$ begin
  if (select count(*) from storage.objects) <> 1 then raise exception 'TEST HATASI: müşteri başkasının dosyalarını listeledi'; end if;
  raise notice 'GEÇTİ: müşteri yalnız kendi dosyasını listeler';
end $$;
update public.profiller
set avatar_url = 'https://ornek/profil/33333333-3333-3333-3333-333333333333/avatar-1.jpg', kapak_odak_y = 0.2
where id = :mA;
do $$ declare n int; begin
  with g as (
    update public.salonlar set kapak_url = 'kotu' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning id
  ) select count(*) into n from g;
  if n <> 0 or (select kapak_url from public.salonlar where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') = 'kotu'
  then raise exception 'TEST HATASI: müşteri salon kapağını değiştirdi'; end if;
  raise notice 'GEÇTİ: müşteri salon kapağını değiştiremez (satır dönmez, uygulama hata gösterir)';
end $$;
do $$ begin
  insert into public.galeri (salon_id, url, herkese_acik) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'x', true);
  raise exception 'TEST HATASI: müşteri galeriye ekledi';
exception when insufficient_privilege then raise notice 'GEÇTİ: müşteri galeriye fotoğraf ekleyemez';
end $$;

-- Doğrudan SQL ile silme engelli; Storage API'nin yaptığı gibi izin verilince kendi dosyası silinir.
do $$ begin
  delete from storage.objects where name like '33333333%';
  raise exception 'TEST HATASI: doğrudan silme engellenmedi';
exception when insufficient_privilege then raise notice 'GEÇTİ: doğrudan silme engelli (Storage API kullanılır)';
end $$;
select set_config('storage.allow_delete_query', 'true', false);
reset role; select set_config('request.jwt.claim.sub', :mB, false); set role authenticated;
delete from storage.objects where bucket_id = 'profil';
reset role;
do $$ begin
  if not exists (select 1 from storage.objects where name like '33333333%') then raise exception 'TEST HATASI: B, A''nın dosyasını sildi'; end if;
  raise notice 'GEÇTİ: başkasının dosyası silinemez';
end $$;
select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
delete from storage.objects where bucket_id = 'profil';
reset role;
do $$ begin
  if exists (select 1 from storage.objects where name like '33333333%') then raise exception 'TEST HATASI: A kendi dosyasını silemedi'; end if;
  raise notice 'GEÇTİ: müşteri kendi dosyasını siler';
end $$;
select set_config('storage.allow_delete_query', 'false', false);

-- Ziyaretçi: keşfet kapak odağı ve vitrin ayarıyla gelir; galeri herkese açık fotoğrafı görür.
select set_config('request.jwt.claim.sub', '', false); set role anon;
select ad, kapak_odak_x, kapak_odak_y, vitrin, logo_url is not null as logo from public.kesfet();
do $$ begin
  if abs((select kapak_odak_y from public.kesfet() limit 1) - 0.7) > 0.001 then raise exception 'TEST HATASI: kapak odağı'; end if;
  if (select vitrin ->> 'filtre' from public.kesfet() limit 1) <> 'sicak' then raise exception 'TEST HATASI: vitrin ayarı'; end if;
  if (select count(*) from public.galeri where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 1 then raise exception 'TEST HATASI: galeri'; end if;
  if (select count(*) from storage.objects) <> 0 then raise exception 'TEST HATASI: ziyaretçi dosya listeledi'; end if;
  raise notice 'GEÇTİ: keşfet kapak odağı ve vitrin ayarıyla geliyor, galeri herkese açık';
end $$;
reset role;

\echo TÜM TESTLER BİTTİ
