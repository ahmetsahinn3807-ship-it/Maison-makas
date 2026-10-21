-- 17–18. adım fonksiyonlarının testleri (01_senaryolar.sql'den bağımsız, temiz veriyle).
\set ON_ERROR_STOP 1
\pset footer off
set client_min_messages = notice;

\set sahip '''11111111-1111-1111-1111-111111111111'''
\set ustaK '''22222222-2222-2222-2222-222222222222'''
\set mA    '''33333333-3333-3333-3333-333333333333'''
\set mB    '''44444444-4444-4444-4444-444444444444'''
\set salon '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''
\set u1    '''b1111111-1111-1111-1111-111111111111'''
\set u2    '''b2222222-2222-2222-2222-222222222222'''
\set h1    '''c1111111-1111-1111-1111-111111111111'''

select ((now() at time zone 'Europe/Istanbul')::date + 2)::text as gun \gset

insert into auth.users (id, email, raw_user_meta_data) values
  (:sahip, 'sahip@test', '{"ad_soyad": "Ahmet Şahin"}'),
  (:ustaK, 'usta@test', '{"ad_soyad": "Mehmet Usta"}'),
  (:mA, 'a@test', '{"ad_soyad": "Ali Kaya"}'),
  (:mB, 'b@test', '{"ad_soyad": "Burak"}');

reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda, sehir, ilce)
values (:salon, :sahip, 'maison-ahmet', 'Maison Ahmet', true, 'İstanbul', 'Sancaktepe')
returning ad;
insert into public.salonlar (sahip_id, kisa_ad, ad, yayinda) values (:sahip, 'gizli-salon', 'Gizli Salon', false);
insert into public.ustalar (id, salon_id, kullanici_id, ad, sira) values
  (:u1, :salon, null, 'Mehmet', 1), (:u2, :salon, null, 'Can', 2);
-- 20. adımdan beri bir hesap ekibe yalnız davet koduyla bağlanır; testte doğrudan bağlanır.
reset role;
update public.ustalar set kullanici_id = :ustaK where id = :u1;
set role authenticated;
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat) values (:h1, :salon, 'Saç kesimi', 30, 400);
insert into public.calisma_saatleri (salon_id, usta_id, gun, baslangic, bitis)
select :salon::uuid, u.id, g, '09:00', '19:00'
from (values (:u1::uuid), (:u2::uuid)) as u (id), generate_series(1, 7) as g;

-- A: Mehmet 10:00 ve Can 11:00; B: Can 10:00
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
select public.randevu_al(:salon, (:'gun'::date + time '10:00') at time zone 'Europe/Istanbul', array[:h1]::uuid[], :u1) as ra1 \gset
select public.randevu_al(:salon, (:'gun'::date + time '11:00') at time zone 'Europe/Istanbul', array[:h1]::uuid[], :u2) as ra2 \gset
reset role; select set_config('request.jwt.claim.sub', :mB, false); set role authenticated;
select public.randevu_al(:salon, (:'gun'::date + time '10:00') at time zone 'Europe/Istanbul', array[:h1]::uuid[], :u2) as rb1 \gset

-- randevularim
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
select salon_ad, usta_ad, to_char(baslangic at time zone 'Europe/Istanbul', 'HH24:MI') as saat, hizmetler, toplam_fiyat, para_birimi
from public.randevularim();
do $$ begin
  if (select count(*) from public.randevularim()) <> 2 then raise exception 'TEST HATASI: yaklaşan randevular'; end if;
  if (select count(*) from public.randevularim(true)) <> 0 then raise exception 'TEST HATASI: geçmiş boş olmalı'; end if;
  if (select usta_ad from public.randevularim() limit 1) <> 'Mehmet' then raise exception 'TEST HATASI: sıralama'; end if;
  raise notice 'GEÇTİ: randevularim yalnız kendi randevularını, saat sırasıyla veriyor';
end $$;
select public.randevu_iptal(:'ra2');
do $$ begin
  if (select count(*) from public.randevularim()) <> 1 or (select count(*) from public.randevularim(true)) <> 1
  then raise exception 'TEST HATASI: iptal edilen geçmişe geçmedi'; end if;
  raise notice 'GEÇTİ: iptal edilen randevu geçmiş listesinde';
end $$;

-- Usta pasife alınsa da müşterinin geçmişi kaybolmaz
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
update public.ustalar set aktif = false where id = :u2;
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
do $$ begin
  if (select count(*) from public.randevularim(true)) <> 1 then raise exception 'TEST HATASI: pasif ustanın randevusu kayboldu'; end if;
  raise notice 'GEÇTİ: pasif ustanın eski randevusu geçmişte duruyor';
end $$;
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
update public.ustalar set aktif = true where id = :u2;

-- kesfet (ziyaretçi)
reset role; select set_config('request.jwt.claim.sub', '', false); set role anon;
select ad, ilce, ortalama, yorum_adet from public.kesfet();
do $$ begin
  if (select count(*) from public.kesfet()) <> 1 then raise exception 'TEST HATASI: gizli salon keşfette'; end if;
  if (select count(*) from public.kesfet('sancak')) <> 1 then raise exception 'TEST HATASI: ilçe araması'; end if;
  if (select count(*) from public.kesfet('kadıköy')) <> 0 then raise exception 'TEST HATASI: yanlış arama sonucu'; end if;
  if (select count(*) from public.kesfet('  ')) <> 1 then raise exception 'TEST HATASI: boş arama'; end if;
  raise notice 'GEÇTİ: keşfet yalnız yayındaki salonları ve aramayı veriyor';
end $$;
do $$ begin
  perform public.randevularim();
  raise exception 'TEST HATASI: ziyaretçi randevularim çağırdı';
exception when insufficient_privilege then raise notice 'GEÇTİ: ziyaretçi randevu listesine erişemiyor';
end $$;

-- salon_takvimi
select set_config('test.bas', ((:'gun'::date) at time zone 'Europe/Istanbul')::text, false);
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select usta_ad, musteri_ad, to_char(baslangic at time zone 'Europe/Istanbul', 'HH24:MI') as saat, durum, hizmetler
from public.salon_takvimi(:salon, (:'gun'::date) at time zone 'Europe/Istanbul', (:'gun'::date + 1) at time zone 'Europe/Istanbul');
do $$
declare b timestamptz := current_setting('test.bas')::timestamptz;
begin
  if (select count(*) from public.salon_takvimi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', b, b + interval '1 day')) <> 3
  then raise exception 'TEST HATASI: sahip takvimi'; end if;
  raise notice 'GEÇTİ: sahip günün tüm takvimini (iptal dahil) görüyor';
end $$;
reset role; select set_config('request.jwt.claim.sub', :ustaK, false); set role authenticated;
do $$
declare b timestamptz := current_setting('test.bas')::timestamptz;
begin
  if (select count(*) from public.salon_takvimi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', b, b + interval '1 day')) <> 1
  then raise exception 'TEST HATASI: usta takvimi'; end if;
  raise notice 'GEÇTİ: usta yalnız kendi randevularını görüyor';
end $$;
reset role; select set_config('request.jwt.claim.sub', :mB, false); set role authenticated;
do $$
declare b timestamptz := current_setting('test.bas')::timestamptz;
begin
  if (select count(*) from public.salon_takvimi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', b, b + interval '1 day')) <> 0
  then raise exception 'TEST HATASI: müşteri salon takvimini gördü'; end if;
  raise notice 'GEÇTİ: müşteri salon takvimini göremiyor';
end $$;

-- hesabimi_sil
do $$ begin
  perform public.hesabimi_sil();
  if exists (select 1 from public.profiller) then raise exception 'TEST HATASI: B silinmedi'; end if;
  raise notice 'GEÇTİ: müşteri hesabını sildi';
end $$;
reset role;
do $$ begin
  if exists (select 1 from auth.users where id = '44444444-4444-4444-4444-444444444444') then raise exception 'TEST HATASI: auth kaydı duruyor'; end if;
  if not exists (select 1 from public.randevular where musteri_id is null) then raise exception 'TEST HATASI: randevu anonimleşmedi'; end if;
  if exists (select 1 from public.randevular where musteri_id is null and durum <> 'iptal') then raise exception 'TEST HATASI: silinen hesabın yaklaşan randevusu iptal edilmedi'; end if;
  raise notice 'GEÇTİ: silinen hesabın yaklaşan randevusu iptal edildi, kayıt salonda adsız kaldı';
end $$;

-- Salon sahibi: müşteri uygulamasından silemez; Makas Pro'dan salonuyla birlikte siler.
select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
do $$ begin
  perform public.hesabimi_sil();
  raise exception 'TEST HATASI: salon sahibi müşteri uygulamasından hesabını sildi';
exception when sqlstate 'P0001' then raise notice 'GEÇTİ: salonu olan hesap müşteri uygulamasından silinmiyor';
end $$;
do $$ begin
  perform public.hesabimi_sil(p_salonlarla => true);
  raise exception 'TEST HATASI: yaklaşan randevusu olan salon silindi';
exception when sqlstate 'P0001' then raise notice 'GEÇTİ: yaklaşan randevu varken salon silinmiyor (%)', sqlerrm;
end $$;
update public.randevular set durum = 'iptal' where salon_id = :salon and durum in ('bekliyor', 'onaylandi');
do $$ begin
  perform public.hesabimi_sil(p_salonlarla => true);
  raise notice 'GEÇTİ: salon sahibi hesabını salonlarıyla birlikte sildi';
end $$;
reset role;
do $$ begin
  if exists (select 1 from auth.users where id = '11111111-1111-1111-1111-111111111111') then raise exception 'TEST HATASI: sahibin auth kaydı duruyor'; end if;
  if exists (select 1 from public.salonlar) then raise exception 'TEST HATASI: salon duruyor'; end if;
  if exists (select 1 from public.ustalar) or exists (select 1 from public.hizmetler)
     or exists (select 1 from public.randevular) or exists (select 1 from public.calisma_saatleri)
  then raise exception 'TEST HATASI: salon verisi kaldı'; end if;
  if not exists (select 1 from public.profiller where id = '22222222-2222-2222-2222-222222222222')
  then raise exception 'TEST HATASI: ustanın kendi hesabı silindi'; end if;
  raise notice 'GEÇTİ: salon verisi temizlendi, ustanın hesabı duruyor';
end $$;

\echo TÜM TESTLER BİTTİ
