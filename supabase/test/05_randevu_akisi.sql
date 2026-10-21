-- 21. adım: randevu akışı ve takvim testleri (temiz veriyle).
\set ON_ERROR_STOP 1
\pset footer off
set client_min_messages = notice;

\set sahip  '''11111111-1111-1111-1111-111111111111'''
\set ustaK  '''22222222-2222-2222-2222-222222222222'''
\set mA     '''33333333-3333-3333-3333-333333333333'''
\set salon  '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''
\set u1     '''b1111111-1111-1111-1111-111111111111'''
\set u2     '''b2222222-2222-2222-2222-222222222222'''
\set u3     '''b3333333-3333-3333-3333-333333333333'''
\set h1     '''c1111111-1111-1111-1111-111111111111'''
\set h2     '''c2222222-2222-2222-2222-222222222222'''
\set h3     '''c3333333-3333-3333-3333-333333333333'''
\set h4     '''c4444444-4444-4444-4444-444444444444'''

insert into auth.users (id, email, raw_user_meta_data) values
  (:sahip, 'sahip@test', '{"ad_soyad": "Ahmet Şahin"}'),
  (:ustaK, 'usta@test', '{"ad_soyad": "Mehmet Usta"}'),
  (:mA, 'a@test', '{"ad_soyad": "Ali Kaya"}');

-- Kurulum: yayındaki salon, 4 hizmet (biri pasif), 3 usta (biri pasif), gelecek pazartesi saatleri.
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda) values (:salon, :sahip, 'maison-ahmet', 'Maison Ahmet', true);
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat, sira, aktif) values
  (:h1, :salon, 'Saç kesimi', 30, 400, 1, true),
  (:h2, :salon, 'Sakal', 20, 250, 2, true),
  (:h3, :salon, 'Saç boyama', 60, 900, 3, true),
  (:h4, :salon, 'Eski hizmet', 30, 100, 4, false);
insert into public.ustalar (id, salon_id, kullanici_id, ad, sira) values (:u1, :salon, :sahip, 'Ahmet', 1);
insert into public.ustalar (id, salon_id, ad, sira) values (:u2, :salon, 'Mehmet', 2);
insert into public.ustalar (id, salon_id, ad, sira, aktif) values (:u3, :salon, 'Can', 3, false);
reset role;
update public.ustalar set kullanici_id = :ustaK where id = :u2;
select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select public.usta_hizmetlerini_kaydet(:u1, array[:h1, :h2]::uuid[]);
select public.usta_hizmetlerini_kaydet(:u2, array[:h1, :h3]::uuid[]);
select public.usta_saatlerini_kaydet(:u1, '[{"gun": 1, "baslangic": "09:00", "bitis": "13:00"}]');
select public.usta_saatlerini_kaydet(:u2, '[{"gun": 1, "baslangic": "10:00", "bitis": "12:00"}]');
select public.usta_saatlerini_kaydet(:u3, '[{"gun": 1, "baslangic": "09:00", "bitis": "20:00"}]');
reset role;

-- Gelecek pazartesi (bugün pazartesiyse bir sonraki)
select set_config('test.gun', (current_date + (8 - extract(isodow from current_date)::int))::text, false);

create function pg_temp.say(p_hizmetler uuid[], p_usta uuid default null, p_gun_sayisi int default 1)
returns integer language sql as $$
  select count(*)::integer from public.musait_saatler(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_setting('test.gun')::date, p_gun_sayisi, p_hizmetler, p_usta)
$$;

-- 1. Boş saatler hizmete ve ustaya göre (ziyaretçi de görebilir).
set role anon; select set_config('request.jwt.claim.sub', '', false);
do $$ begin
  -- Saç kesimi (30 dk): Ahmet 09:00–12:30 (15) + Mehmet 10:00–11:30 (7); pasif Can yok.
  if pg_temp.say(array['c1111111-1111-1111-1111-111111111111']::uuid[]) <> 22
  then raise exception 'TEST HATASI: saç kesimi %', pg_temp.say(array['c1111111-1111-1111-1111-111111111111']::uuid[]); end if;
  -- Saç boyama (60 dk): yalnız Mehmet yapar, 10:00–11:00 (5).
  if pg_temp.say(array['c3333333-3333-3333-3333-333333333333']::uuid[]) <> 5
  then raise exception 'TEST HATASI: boyama %', pg_temp.say(array['c3333333-3333-3333-3333-333333333333']::uuid[]); end if;
  -- Saç + sakal (50 dk): yalnız Ahmet ikisini de yapar, 09:00–12:00 (13).
  if pg_temp.say(array['c1111111-1111-1111-1111-111111111111', 'c2222222-2222-2222-2222-222222222222']::uuid[]) <> 13
  then raise exception 'TEST HATASI: saç ve sakal'; end if;
  raise notice 'GEÇTİ: boş saatler seçilen hizmetin süresine ve o hizmeti yapan ustalara göre';
end $$;
do $$ begin
  if pg_temp.say(array['c4444444-4444-4444-4444-444444444444']::uuid[]) <> 0
     or pg_temp.say(array['c9999999-9999-9999-9999-999999999999']::uuid[]) <> 0
     or pg_temp.say('{}'::uuid[]) <> 0
  then raise exception 'TEST HATASI: pasif, olmayan ya da boş hizmetle saat çıktı'; end if;
  if pg_temp.say(array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b2222222-2222-2222-2222-222222222222') <> 7
  then raise exception 'TEST HATASI: usta süzgeci'; end if;
  if pg_temp.say(array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b3333333-3333-3333-3333-333333333333') <> 0
  then raise exception 'TEST HATASI: pasif usta'; end if;
  raise notice 'GEÇTİ: pasif ya da olmayan hizmet, pasif usta saat vermez; usta seçimi süzer';
end $$;
do $$ declare n int; begin
  select count(*) into n from public.musait_saatler(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 14,
    array['c1111111-1111-1111-1111-111111111111']::uuid[], null);
  if n < 22 then raise exception 'TEST HATASI: 14 günlük arama %', n; end if;
  select count(*) into n from public.musait_saatler(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 14,
    array['c1111111-1111-1111-1111-111111111111']::uuid[], null) m
  where m.baslangic < now();
  if n <> 0 then raise exception 'TEST HATASI: geçmiş saat listelendi'; end if;
  raise notice 'GEÇTİ: çok günlü arama çalışıyor, geçmiş saat yok';
end $$;
reset role;

-- 2. Müşteri randevu alır; o saat ve çakışan başlangıçlar listeden düşer.
select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
select set_config('test.r1', public.randevu_al(:salon,
  (current_setting('test.gun')::date + time '10:00') at time zone 'Europe/Istanbul',
  array[:h1]::uuid[], :u2, 'Kısa olsun')::text, false);
do $$ begin
  if pg_temp.say(array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b2222222-2222-2222-2222-222222222222') <> 5
  then raise exception 'TEST HATASI: alınan saat düşmedi'; end if;
  raise notice 'GEÇTİ: alınan randevu Mehmet''in boş saatlerinden düştü (10:00 ve 10:15)';
end $$;
do $$ begin
  perform public.dukkan_randevusu('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b1111111-1111-1111-1111-111111111111',
    now() + interval '1 day', array['c1111111-1111-1111-1111-111111111111']::uuid[], 'X');
  raise exception 'TEST HATASI: müşteri dükkân randevusu yazdı';
exception when insufficient_privilege then raise notice 'GEÇTİ: müşteri takvime doğrudan yazamaz';
end $$;
reset role;

-- 3. Usta kapıdan gelen müşteriyi kendi takvimine yazar; başkasınınkine yazamaz; çakışma yazılmaz.
select set_config('request.jwt.claim.sub', :ustaK, false); set role authenticated;
select set_config('test.r2', public.dukkan_randevusu(:salon, :u2,
  (current_setting('test.gun')::date + time '11:00') at time zone 'Europe/Istanbul',
  array[:h1]::uuid[], 'Kapıdan Veli', '0532 000 00 00')::text, false);
do $$ declare r record; begin
  select * into r from public.randevular where id = current_setting('test.r2')::uuid;
  if r.kaynak <> 'dukkan' or r.misafir_ad <> 'Kapıdan Veli' or r.toplam_fiyat <> 400
     or upper(r.aralik) - lower(r.aralik) <> interval '30 minutes' then
    raise exception 'TEST HATASI: dükkân randevusu %', r;
  end if;
  if (select count(*) from public.randevu_hizmetleri where randevu_id = r.id) <> 1 then
    raise exception 'TEST HATASI: hizmet kaydı yok';
  end if;
  raise notice 'GEÇTİ: usta kapıdan gelen müşteriyi yazdı (dükkân, 30 dk, ₺400)';
end $$;
do $$ begin
  perform public.dukkan_randevusu('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b1111111-1111-1111-1111-111111111111',
    now() + interval '2 days', '{}'::uuid[], 'Y', null, null, 30);
  raise exception 'TEST HATASI: usta başkasının takvimine yazdı';
exception when insufficient_privilege then raise notice 'GEÇTİ: usta başka ustanın takvimine yazamaz';
end $$;
do $$ begin
  perform public.dukkan_randevusu('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b2222222-2222-2222-2222-222222222222',
    (current_setting('test.gun')::date + time '11:15') at time zone 'Europe/Istanbul', '{}'::uuid[], 'Z', null, null, 30);
  raise exception 'TEST HATASI: çakışan kayıt yazıldı';
exception when raise_exception then raise notice 'GEÇTİ: çakışan saat yazılmadı (%)', sqlerrm;
end $$;
reset role;

-- 4. Salon sahibi süreyle (hizmetsiz) yazar ve mola ekler; mola saatleri listeden düşürür.
select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select public.dukkan_randevusu(:salon, :u1, (current_setting('test.gun')::date + time '09:00') at time zone 'Europe/Istanbul',
  '{}'::uuid[], null, null, 'Telefonla aradı', 45);
do $$ begin
  if (select misafir_ad from public.randevular where usta_id = 'b1111111-1111-1111-1111-111111111111' and kaynak = 'dukkan') <> 'Misafir'
  then raise exception 'TEST HATASI: adsız misafir'; end if;
  raise notice 'GEÇTİ: sahip hizmet seçmeden 45 dakikalık kayıt yazdı (Misafir)';
end $$;
select set_config('test.b1', public.blok_ekle(:u1,
  (current_setting('test.gun')::date + time '12:00') at time zone 'Europe/Istanbul',
  (current_setting('test.gun')::date + time '13:00') at time zone 'Europe/Istanbul', 'Öğle arası')::text, false);
do $$ begin
  -- Ahmet: 09:00–09:45 dolu, 12:00–13:00 mola → saç kesimi için 09:45–11:30 (8 başlangıç)
  if pg_temp.say(array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b1111111-1111-1111-1111-111111111111') <> 8
  then raise exception 'TEST HATASI: mola sonrası % saat',
    pg_temp.say(array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b1111111-1111-1111-1111-111111111111'); end if;
  raise notice 'GEÇTİ: mola ve dükkân randevusu boş saatlerden düştü';
end $$;
do $$ begin
  perform public.blok_ekle('b2222222-2222-2222-2222-222222222222',
    (current_setting('test.gun')::date + time '10:00') at time zone 'Europe/Istanbul',
    (current_setting('test.gun')::date + time '10:30') at time zone 'Europe/Istanbul');
  raise exception 'TEST HATASI: randevunun üstüne mola yazıldı';
exception when raise_exception then raise notice 'GEÇTİ: randevunun üstüne mola yazılmaz';
end $$;
do $$ begin
  perform public.blok_ekle('b1111111-1111-1111-1111-111111111111', now() + interval '3 days', now() + interval '3 days 13 hours');
  raise exception 'TEST HATASI: 13 saatlik mola';
exception when invalid_parameter_value then raise notice 'GEÇTİ: 12 saatten uzun mola reddedildi';
end $$;
-- Mola silinebilir (doğrudan, RLS ile)
delete from public.randevular where id = current_setting('test.b1')::uuid;
do $$ begin
  if exists (select 1 from public.randevular where id = current_setting('test.b1')::uuid)
  then raise exception 'TEST HATASI: mola silinemedi'; end if;
  raise notice 'GEÇTİ: sahip molayı silebilir';
end $$;

-- 5. Durumlar: gelecekteki randevu "geldi" işaretlenemez; geçmiş randevu işaretlenir ve geri alınır.
do $$ begin
  perform public.randevu_durumu(current_setting('test.r1')::uuid, 'tamamlandi');
  raise exception 'TEST HATASI: gelecek randevu tamamlandı';
exception when invalid_parameter_value then raise notice 'GEÇTİ: saati gelmemiş randevu "geldi" işaretlenmez';
end $$;
reset role;
insert into public.randevular (id, salon_id, usta_id, musteri_id, aralik, durum, kaynak)
values ('d1111111-1111-1111-1111-111111111111', :salon, :u2, :mA,
        tstzrange(now() - interval '2 hours', now() - interval '90 minutes', '[)'), 'onaylandi', 'uygulama');
select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select public.randevu_durumu('d1111111-1111-1111-1111-111111111111', 'tamamlandi');
select public.randevu_durumu('d1111111-1111-1111-1111-111111111111', 'gelmedi');
select public.randevu_durumu('d1111111-1111-1111-1111-111111111111', 'onaylandi');
do $$ begin
  if (select durum from public.randevular where id = 'd1111111-1111-1111-1111-111111111111') <> 'onaylandi'
  then raise exception 'TEST HATASI: durum'; end if;
  perform public.randevu_durumu('d1111111-1111-1111-1111-111111111111', 'iptal');
  raise exception 'TEST HATASI: durumla iptal';
exception when invalid_parameter_value then raise notice 'GEÇTİ: geldi, gelmedi ve geri al çalışıyor; iptal ayrı fonksiyonda';
end $$;
reset role;
select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
do $$ begin
  perform public.randevu_durumu('d1111111-1111-1111-1111-111111111111', 'tamamlandi');
  raise exception 'TEST HATASI: müşteri durum değiştirdi';
exception when insufficient_privilege then raise notice 'GEÇTİ: müşteri durum değiştiremez';
end $$;
reset role;

-- 6. Takvim: sahip bütün kayıtları, usta yalnız kendininkini görür.
select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
do $$ declare n int; begin
  select count(*) into n from public.salon_takvimi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - interval '1 day', now() + interval '8 days');
  if n <> 4 then raise exception 'TEST HATASI: sahip takvimi %', n; end if;
  raise notice 'GEÇTİ: sahip takvimde bütün kayıtları görüyor';
end $$;
reset role;
select set_config('request.jwt.claim.sub', :ustaK, false); set role authenticated;
do $$ declare n int; begin
  select count(*) into n from public.salon_takvimi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - interval '1 day', now() + interval '8 days');
  if n <> 3 then raise exception 'TEST HATASI: usta takvimi %', n; end if;
  raise notice 'GEÇTİ: usta yalnız kendi kayıtlarını görüyor';
end $$;
reset role;

-- 7. Anonim ziyaretçi yazma fonksiyonlarını çağıramaz.
set role anon;
do $$ begin
  perform public.blok_ekle('b1111111-1111-1111-1111-111111111111', now() + interval '1 day', now() + interval '25 hours');
  raise exception 'TEST HATASI: anonim mola yazdı';
exception when insufficient_privilege then raise notice 'GEÇTİ: anonim ziyaretçi takvime yazamaz';
end $$;
reset role;

do $$ begin raise notice 'TÜM TESTLER BİTTİ'; end $$;
