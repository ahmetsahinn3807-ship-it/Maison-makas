-- Yerel test senaryoları: sahip, usta, iki müşteri ve ziyaretçi (anon).
-- Her "TEST HATASI" bir kuralın bozulduğunu gösterir; betik ilk hatada durur.
\set ON_ERROR_STOP 1
\pset footer off
set client_min_messages = notice;

-- Sabit kimlikler
\set sahip   '''11111111-1111-1111-1111-111111111111'''
\set ustaK   '''22222222-2222-2222-2222-222222222222'''
\set mA      '''33333333-3333-3333-3333-333333333333'''
\set mB      '''44444444-4444-4444-4444-444444444444'''
\set salon   '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''
\set u1      '''b1111111-1111-1111-1111-111111111111'''
\set u2      '''b2222222-2222-2222-2222-222222222222'''
\set h1      '''c1111111-1111-1111-1111-111111111111'''
\set h2      '''c2222222-2222-2222-2222-222222222222'''
\set h3      '''c3333333-3333-3333-3333-333333333333'''

-- Test günü: İstanbul saatiyle 2 gün sonrası
select ((now() at time zone 'Europe/Istanbul')::date + 2)::text as gun \gset
\echo Test günü: :gun

-- 0) Hesaplar → profiller tetikleyiciyle oluşmalı
insert into auth.users (id, email, raw_user_meta_data) values
  (:sahip, 'sahip@test', '{"ad_soyad": "Ahmet Şahin"}'),
  (:ustaK, 'usta@test', '{"ad_soyad": "Mehmet Usta"}'),
  (:mA, 'a@test', '{"ad_soyad": "Ali Kaya"}'),
  (:mB, 'b@test', '{"ad_soyad": "Burak"}');
do $$ begin
  if (select count(*) from public.profiller) <> 4 then raise exception 'TEST HATASI: profiller oluşmadı'; end if;
  raise notice 'GEÇTİ: yeni hesapta profil oluşuyor';
end $$;

-- 1) SAHİP: salon açar (RETURNING ile), doğrulama rozetini kendine veremez
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda, dogrulandi, sehir, ilce)
values (:salon, :sahip, 'maison-ahmet', 'Maison Ahmet', true, true, 'İstanbul', 'Sancaktepe')
returning ad, dogrulandi;
do $$ begin
  if (select dogrulandi from public.salonlar) then raise exception 'TEST HATASI: sahip rozeti kendine verdi'; end if;
  raise notice 'GEÇTİ: sahip salon açtı, doğrulama rozeti kapalı kaldı';
end $$;

update public.salonlar set dogrulandi = true, sahip_id = '33333333-3333-3333-3333-333333333333';
do $$ begin
  if (select dogrulandi or sahip_id <> '11111111-1111-1111-1111-111111111111' from public.salonlar)
  then raise exception 'TEST HATASI: korumalı alan değişti'; end if;
  raise notice 'GEÇTİ: rozet ve sahiplik korunuyor';
end $$;

do $$ begin
  update public.salonlar set saat_dilimi = 'Mars/Olympus';
  raise exception 'TEST HATASI: geçersiz saat dilimi kabul edildi';
exception when invalid_parameter_value then raise notice 'GEÇTİ: geçersiz saat dilimi reddedildi';
end $$;

-- Ustalar, hizmetler, usta_hizmet, çalışma saatleri
insert into public.ustalar (id, salon_id, kullanici_id, ad, sira) values
  (:u1, :salon, :ustaK, 'Mehmet', 1),
  (:u2, :salon, null, 'Can', 2);
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat, kategori, sira) values
  (:h1, :salon, 'Saç kesimi', 30, 400, 'sac', 1),
  (:h2, :salon, 'Sakal', 20, 250, 'sakal', 2),
  (:h3, :salon, 'Boya', 60, 900, 'renk', 3);
insert into public.usta_hizmet (salon_id, usta_id, hizmet_id) values
  (:salon, :u2, :h1), (:salon, :u2, :h2);
insert into public.calisma_saatleri (salon_id, usta_id, gun, baslangic, bitis)
select :salon::uuid, u.id, g, y.s, y.e
from (values (:u1::uuid), (:u2::uuid)) as u (id),
     generate_series(1, 7) as g,
     (values ('09:00'::time, '13:00'::time), ('14:00'::time, '19:00'::time)) as y (s, e);
do $$ begin
  if (select count(*) from public.calisma_saatleri) <> 28 then raise exception 'TEST HATASI: çalışma saatleri'; end if;
  raise notice 'GEÇTİ: sahip usta, hizmet ve çalışma saati ekledi';
end $$;

-- 2) ZİYARETÇİ (anon): salonu, ustaları, hizmetleri ve boş saatleri görür; randevu alamaz
reset role; select set_config('request.jwt.claim.sub', '', false); set role anon;
do $$ begin
  if (select count(*) from public.salonlar) <> 1 then raise exception 'TEST HATASI: anon salonu göremedi'; end if;
  if (select count(*) from public.ustalar) <> 2 then raise exception 'TEST HATASI: anon ustaları göremedi'; end if;
  if (select count(*) from public.hizmetler) <> 3 then raise exception 'TEST HATASI: anon hizmetleri göremedi'; end if;
  if (select count(*) from public.profiller) <> 0 then raise exception 'TEST HATASI: anon profil gördü'; end if;
  if (select count(*) from public.randevular) <> 0 then raise exception 'TEST HATASI: anon randevu gördü'; end if;
  raise notice 'GEÇTİ: ziyaretçi yalnız herkese açık veriyi görüyor';
end $$;
select to_char(min(baslangic) at time zone 'Europe/Istanbul', 'HH24:MI') as ilk_bos_saat,
       to_char(max(baslangic) at time zone 'Europe/Istanbul', 'HH24:MI') as son_bos_saat,
       count(*) as bos_saat_sayisi
from public.bos_saatler(:salon, :'gun', 50, :u1);
do $$ begin
  insert into public.salonlar (sahip_id, kisa_ad, ad) values ('33333333-3333-3333-3333-333333333333', 'sahte', 'Sahte');
  raise exception 'TEST HATASI: anon salon açtı';
exception when insufficient_privilege then raise notice 'GEÇTİ: ziyaretçi salon açamıyor';
end $$;
do $$ begin
  perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '2 days',
    array['c1111111-1111-1111-1111-111111111111']::uuid[]);
  raise exception 'TEST HATASI: anon randevu aldı';
exception when insufficient_privilege then raise notice 'GEÇTİ: ziyaretçi randevu alamıyor';
end $$;

-- 3) MÜŞTERİ A: Mehmet'ten 10:00'a saç + sakal (50 dk)
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
select public.randevu_al(:salon, (:'gun'::date + time '10:00') at time zone 'Europe/Istanbul',
  array[:h1, :h2]::uuid[], :u1, 'Yanlar kısa olsun') as randevu_a \gset
select to_char(lower(aralik) at time zone 'Europe/Istanbul', 'HH24:MI') || '–' ||
       to_char(upper(aralik) at time zone 'Europe/Istanbul', 'HH24:MI') as saat,
       toplam_fiyat, durum
from public.randevular where id = :'randevu_a';
do $$ begin
  if (select count(*) from public.randevu_hizmetleri) <> 2 then raise exception 'TEST HATASI: randevu hizmetleri'; end if;
  if (select toplam_fiyat from public.randevular) <> 650 then raise exception 'TEST HATASI: fiyat sunucuda hesaplanmadı'; end if;
  raise notice 'GEÇTİ: müşteri randevu aldı, fiyat ve süre sunucuda hesaplandı';
end $$;

do $$ begin
  insert into public.randevular (salon_id, usta_id, musteri_id, aralik)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b1111111-1111-1111-1111-111111111111',
          '33333333-3333-3333-3333-333333333333', tstzrange(now() + interval '3 days', now() + interval '3 days 1 hour'));
  raise exception 'TEST HATASI: müşteri randevuyu doğrudan yazdı';
exception when insufficient_privilege then raise notice 'GEÇTİ: müşteri randevuyu yalnız randevu_al ile alabiliyor';
end $$;

do $$ begin
  perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() - interval '1 day',
    array['c1111111-1111-1111-1111-111111111111']::uuid[]);
  raise exception 'TEST HATASI: geçmişe randevu alındı';
exception when sqlstate 'P0001' then raise notice 'GEÇTİ: geçmiş saate randevu yok';
end $$;

-- Öğle arası (13:30) ve kapanışı taşan (18:45 + 30 dk) saatler reddedilmeli; 18:30 kabul
do $$
declare g date := ((now() at time zone 'Europe/Istanbul')::date + 2);
begin
  begin
    perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '13:30') at time zone 'Europe/Istanbul',
      array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b1111111-1111-1111-1111-111111111111');
    raise exception 'TEST HATASI: öğle arasına randevu alındı';
  exception when sqlstate 'P0001' then raise notice 'GEÇTİ: öğle arasına randevu yok';
  end;
  begin
    perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '18:45') at time zone 'Europe/Istanbul',
      array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b1111111-1111-1111-1111-111111111111');
    raise exception 'TEST HATASI: kapanışı taşan randevu alındı';
  exception when sqlstate 'P0001' then raise notice 'GEÇTİ: kapanışı taşan randevu yok';
  end;
end $$;

-- 4) MÜŞTERİ B
reset role; select set_config('request.jwt.claim.sub', :mB, false); set role authenticated;
do $$
declare g date := ((now() at time zone 'Europe/Istanbul')::date + 2);
begin
  perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '10:30') at time zone 'Europe/Istanbul',
    array['c1111111-1111-1111-1111-111111111111']::uuid[], 'b1111111-1111-1111-1111-111111111111');
  raise exception 'TEST HATASI: dolu saate ikinci randevu alındı';
exception when sqlstate 'P0001' then raise notice 'GEÇTİ: dolu saate ikinci randevu yok';
end $$;
-- "Fark etmez": aynı saat boş olan Can'a gitmeli
select public.randevu_al(:salon, (:'gun'::date + time '10:30') at time zone 'Europe/Istanbul',
  array[:h1]::uuid[]) as randevu_b \gset
do $$ begin
  if (select u.ad from public.randevular r join public.ustalar u on u.id = r.usta_id) <> 'Can'
  then raise exception 'TEST HATASI: fark etmez yanlış ustaya gitti'; end if;
  raise notice 'GEÇTİ: "Fark etmez" boş ustaya (Can) atadı';
end $$;
-- Boya'yı Can yapmıyor: fark etmez → Mehmet'e gitmeli; Can'a zorlanırsa reddedilmeli
select public.randevu_al(:salon, (:'gun'::date + time '15:00') at time zone 'Europe/Istanbul',
  array[:h3]::uuid[]) as randevu_b2 \gset
do $$ begin
  if (select u.ad from public.randevular r join public.ustalar u on u.id = r.usta_id
      where r.id = (select id from public.randevular order by lower(aralik) desc limit 1)) <> 'Mehmet'
  then raise exception 'TEST HATASI: hizmeti yapamayan ustaya atandı'; end if;
  raise notice 'GEÇTİ: hizmeti yapan ustaya atandı';
end $$;
do $$
declare g date := ((now() at time zone 'Europe/Istanbul')::date + 2);
begin
  perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '16:00') at time zone 'Europe/Istanbul',
    array['c3333333-3333-3333-3333-333333333333']::uuid[], 'b2222222-2222-2222-2222-222222222222');
  raise exception 'TEST HATASI: usta yapmadığı hizmete atandı';
exception when sqlstate 'P0001' then raise notice 'GEÇTİ: usta yapmadığı hizmete atanmıyor';
end $$;
do $$ begin
  if (select count(*) from public.randevular) <> 2 then raise exception 'TEST HATASI: B başkasının randevusunu görüyor'; end if;
  if (select count(*) from public.profiller) <> 1 then raise exception 'TEST HATASI: B başkasının profilini görüyor'; end if;
  update public.randevular set durum = 'iptal' where musteri_id = '33333333-3333-3333-3333-333333333333';
  if found then raise exception 'TEST HATASI: B, A''nın randevusunu değiştirdi'; end if;
  raise notice 'GEÇTİ: müşteri yalnız kendi randevusunu ve profilini görüyor';
end $$;

-- 5) USTA (Mehmet, kendi hesabıyla): yalnız kendi takvimi; müşterisinin profilini görür; blok ekler
reset role; select set_config('request.jwt.claim.sub', :ustaK, false); set role authenticated;
do $$ begin
  if (select count(*) from public.randevular) <> 2 then raise exception 'TEST HATASI: usta takvimi yanlış (% satır)', (select count(*) from public.randevular); end if;
  if not exists (select 1 from public.profiller where ad_soyad = 'Ali Kaya') then raise exception 'TEST HATASI: usta müşterisini göremiyor'; end if;
  raise notice 'GEÇTİ: usta yalnız kendi takvimini ve müşterilerini görüyor';
end $$;
insert into public.randevular (salon_id, usta_id, tur, aralik)
values (:salon, :u1, 'blok', tstzrange((:'gun'::date + time '12:00') at time zone 'Europe/Istanbul',
                                       (:'gun'::date + time '13:00') at time zone 'Europe/Istanbul'));
do $$
declare g date := ((now() at time zone 'Europe/Istanbul')::date + 2);
begin
  insert into public.randevular (salon_id, usta_id, tur, aralik)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b1111111-1111-1111-1111-111111111111', 'blok',
          tstzrange((g + time '12:30') at time zone 'Europe/Istanbul', (g + time '13:30') at time zone 'Europe/Istanbul'));
  raise exception 'TEST HATASI: çakışan blok yazıldı';
exception when exclusion_violation then raise notice 'GEÇTİ: çifte kayıt engeli çalışıyor (cifte_randevu_engeli)';
end $$;
do $$
declare g date := ((now() at time zone 'Europe/Istanbul')::date + 2);
begin
  if exists (select 1 from public.bos_saatler('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', g, 30, 'b1111111-1111-1111-1111-111111111111')
             where baslangic = (g + time '12:00') at time zone 'Europe/Istanbul')
  then raise exception 'TEST HATASI: blok saati boş görünüyor'; end if;
  raise notice 'GEÇTİ: blok saatleri boş saatlerden düşüyor';
end $$;
do $$ begin
  insert into public.randevular (salon_id, usta_id, tur, aralik)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'b2222222-2222-2222-2222-222222222222', 'blok',
          tstzrange(now() + interval '5 days', now() + interval '5 days 1 hour'));
  raise exception 'TEST HATASI: usta başka ustanın takvimine yazdı';
exception when insufficient_privilege then raise notice 'GEÇTİ: usta başka ustanın takvimine yazamıyor';
end $$;

-- 6) SAHİP: tüm takvimi görür, randevuyu tamamlar
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
do $$ begin
  if (select count(*) from public.randevular) <> 4 then raise exception 'TEST HATASI: sahip tüm takvimi göremiyor'; end if;
  raise notice 'GEÇTİ: sahip salonun tüm takvimini görüyor';
end $$;
update public.randevular set durum = 'tamamlandi' where id = :'randevu_a';

-- 7) YORUM: yalnız tamamlanan randevunun müşterisi, bir kez
reset role; select set_config('request.jwt.claim.sub', :mB, false); set role authenticated;
do $$ begin
  perform public.yorum_yaz((select id from public.randevular limit 1), 5, 'Süper');
  raise exception 'TEST HATASI: tamamlanmamış randevuya yorum yazıldı';
exception when sqlstate '22023' then raise notice 'GEÇTİ: tamamlanmamış randevuya yorum yok';
end $$;
do $$ begin
  perform public.yorum_yaz('00000000-0000-0000-0000-000000000000', 5, 'Sahte');
  raise exception 'TEST HATASI: yabancı randevuya yorum yazıldı';
exception when sqlstate 'P0002' then raise notice 'GEÇTİ: başkasının randevusuna yorum yok';
end $$;
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
select public.yorum_yaz(:'randevu_a', 5, 'Usta ellere teslim, harika oldu.') is not null as yorum_yazildi;
do $$ begin
  perform public.yorum_yaz((select id from public.randevular where durum = 'tamamlandi'), 4, 'Tekrar');
  raise exception 'TEST HATASI: aynı randevuya ikinci yorum';
exception when unique_violation then raise notice 'GEÇTİ: randevu başına tek yorum';
end $$;
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select public.yorum_yanitla((select id from public.yorumlar), 'Teşekkürler, yine bekleriz!');
reset role; select set_config('request.jwt.claim.sub', '', false); set role anon;
select gorunen_ad, puan, metin, yanit from public.yorumlar;
select ortalama, adet from public.salon_puanlari;

-- 8) İPTAL
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
do $$ begin
  perform public.randevu_iptal((select r.id from public.randevular r limit 1));
  raise exception 'TEST HATASI: tamamlanmış randevu iptal edildi';
exception when sqlstate '22023' then raise notice 'GEÇTİ: tamamlanmış randevu iptal edilmiyor';
end $$;
reset role; select set_config('request.jwt.claim.sub', :mB, false); set role authenticated;
select public.randevu_iptal(:'randevu_b');
do $$ begin
  if (select durum || '/' || gec_iptal from public.randevular where durum = 'iptal') <> 'iptal/false'
  then raise exception 'TEST HATASI: iptal kaydı'; end if;
  raise notice 'GEÇTİ: müşteri kendi randevusunu iptal etti (geç iptal değil)';
end $$;
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
do $$ begin
  perform public.randevu_iptal('00000000-0000-0000-0000-000000000000');
  raise exception 'TEST HATASI';
exception when sqlstate 'P0002' then raise notice 'GEÇTİ: olmayan randevu';
end $$;
select set_config('test.randevu_b2', :'randevu_b2', false);
do $$ begin
  perform public.randevu_iptal(current_setting('test.randevu_b2')::uuid);
  raise exception 'TEST HATASI: A, B''nin randevusunu iptal etti';
exception when insufficient_privilege then raise notice 'GEÇTİ: başkasının randevusu iptal edilemiyor';
end $$;
do $$
declare g date := ((now() at time zone 'Europe/Istanbul')::date + 2);
begin
  if not exists (select 1 from public.bos_saatler('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', g, 30, 'b2222222-2222-2222-2222-222222222222')
                 where baslangic = (g + time '10:30') at time zone 'Europe/Istanbul')
  then raise exception 'TEST HATASI: iptal edilen saat boşalmadı'; end if;
  raise notice 'GEÇTİ: iptal edilen saat yeniden boş';
end $$;

-- 8b) Kötüye kullanım sınırları ve iç fonksiyonlar
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
do $$
declare g date := ((now() at time zone 'Europe/Istanbul')::date + 3);
begin
  perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '09:00') at time zone 'Europe/Istanbul',
    array['c1111111-1111-1111-1111-111111111111']::uuid[]);
  perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '10:00') at time zone 'Europe/Istanbul',
    array['c1111111-1111-1111-1111-111111111111']::uuid[]);
  perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '11:00') at time zone 'Europe/Istanbul',
    array['c1111111-1111-1111-1111-111111111111']::uuid[]);
  begin
    perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', (g + time '15:00') at time zone 'Europe/Istanbul',
      array['c1111111-1111-1111-1111-111111111111']::uuid[]);
    raise exception 'TEST HATASI: dördüncü ileri tarihli randevu alındı';
  exception when sqlstate 'P0001' then raise notice 'GEÇTİ: bir salonda en fazla 3 ileri tarihli randevu';
  end;
  begin
    perform public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '120 days',
      array['c1111111-1111-1111-1111-111111111111']::uuid[]);
    raise exception 'TEST HATASI: 90 günden ileriye randevu alındı';
  exception when sqlstate 'P0001' then raise notice 'GEÇTİ: 90 günden ileriye randevu yok';
  end;
  begin
    perform public.usta_uygun_mu('b1111111-1111-1111-1111-111111111111', now() + interval '1 day', 30);
    raise exception 'TEST HATASI: iç fonksiyon dışarıdan çağrıldı';
  exception when insufficient_privilege then raise notice 'GEÇTİ: iç fonksiyon dışarıya kapalı';
  end;
end $$;

-- 9) Silme kuralları (postgres olarak)
reset role; select set_config('request.jwt.claim.sub', '', false);
do $$ begin
  delete from public.ustalar where id = 'b1111111-1111-1111-1111-111111111111';
  raise exception 'TEST HATASI: randevusu olan usta silindi';
exception when foreign_key_violation then raise notice 'GEÇTİ: randevusu olan usta silinmiyor (pasife alınır)';
end $$;
do $$ begin
  delete from auth.users where id = '11111111-1111-1111-1111-111111111111';
  raise exception 'TEST HATASI: salon sahibi hesabı salon dururken silindi';
exception when foreign_key_violation then raise notice 'GEÇTİ: salonu olan hesap önce salonu kapatmalı';
end $$;
delete from auth.users where id = '44444444-4444-4444-4444-444444444444';
do $$ begin
  if exists (select 1 from public.randevular where musteri_id = '44444444-4444-4444-4444-444444444444')
  then raise exception 'TEST HATASI: silinen müşterinin kimliği kaldı'; end if;
  raise notice 'GEÇTİ: hesabı silinen müşterinin randevuları anonim kaldı';
end $$;
delete from public.salonlar where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
do $$ begin
  if (select count(*) from public.randevular) + (select count(*) from public.ustalar) + (select count(*) from public.yorumlar) <> 0
  then raise exception 'TEST HATASI: salon silinince bağlı kayıtlar kaldı'; end if;
  raise notice 'GEÇTİ: salon silinince tüm bağlı kayıtlar silindi';
end $$;

\echo TÜM TESTLER BİTTİ
