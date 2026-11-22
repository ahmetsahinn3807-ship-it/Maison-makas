-- Güvenlik denemeleri: başka salonun sahibi, yabancı hesap ve ziyaretçi (anon) saldırgan gibi davranır.
-- Her "TEST HATASI" bir saldırının başarılı olduğunu (yani açık olduğunu) gösterir; betik ilk hatada durur.
\set ON_ERROR_STOP 1
set client_min_messages = notice;

\set sA   '''11111111-1111-1111-1111-111111111111'''
\set sB   '''22222222-2222-2222-2222-222222222222'''
\set yab  '''33333333-3333-3333-3333-333333333333'''
\set salA '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''
\set salB '''bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'''
\set uA   '''a1111111-1111-1111-1111-111111111111'''
\set uB   '''b1111111-1111-1111-1111-111111111111'''
\set hA   '''c1111111-1111-1111-1111-111111111111'''
\set hB   '''c2222222-2222-2222-2222-222222222222'''

-- Yardımcılar: saldırı başarısız olmalı (hata ya da 0 satır)
create or replace function pg_temp.hata_bekle(p_ad text, p_sorgu text) returns void language plpgsql as $$
begin
  begin
    execute p_sorgu;
  exception when others then
    raise notice 'GEÇTİ: % (%)', p_ad, left(sqlerrm, 60);
    return;
  end;
  raise exception 'TEST HATASI: saldırı başardı → %', p_ad;
end $$;
create or replace function pg_temp.sifir_bekle(p_ad text, p_sorgu text) returns void language plpgsql as $$
declare n bigint;
begin
  execute p_sorgu into n;
  if coalesce(n, 0) <> 0 then raise exception 'TEST HATASI: saldırı başardı (% satır) → %', n, p_ad; end if;
  raise notice 'GEÇTİ: %', p_ad;
end $$;
grant execute on function pg_temp.hata_bekle(text, text), pg_temp.sifir_bekle(text, text) to anon, authenticated;

-- Hesaplar, iki salon
reset role;
insert into auth.users (id, email, raw_user_meta_data) values
  (:sA, 'a@t', '{"ad_soyad":"Sahip A"}'), (:sB, 'b@t', '{"ad_soyad":"Sahip B"}'), (:yab, 'y@t', '{"ad_soyad":"Yabancı"}');

select set_config('request.jwt.claim.sub', :sA, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda) values (:salA, :sA, 'salon-a', 'Salon A', true);
insert into public.ustalar (id, salon_id, ad, sira) values (:uA, :salA, 'Usta A', 1);
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat, kategori, sira, hedef) values (:hA, :salA, 'Kesim A', 30, 400, 'sac', 1, 'bay');
insert into public.calisma_saatleri (salon_id, usta_id, gun, baslangic, bitis)
select :salA::uuid, :uA::uuid, g, '09:00', '19:00' from generate_series(1, 7) g;

reset role; select set_config('request.jwt.claim.sub', :sB, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda) values (:salB, :sB, 'salon-b', 'Salon B', true);
insert into public.ustalar (id, salon_id, ad, sira) values (:uB, :salB, 'Usta B', 1);
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat, kategori, sira, hedef) values (:hB, :salB, 'Kesim B', 30, 400, 'sac', 1, 'bay');
insert into public.calisma_saatleri (salon_id, usta_id, gun, baslangic, bitis)
select :salB::uuid, :uB::uuid, g, '09:00', '19:00' from generate_series(1, 7) g;

-- Salon A'ya ziyaretçi bir QR randevusu alır
reset role; select set_config('request.jwt.claim.sub', '', false); set role anon;
select public.qr_sepet_randevu_al(:salA, 'Gizli Müşteri', '05321112233',
  jsonb_build_array(jsonb_build_object('kisi', 'Gizli Müşteri',
    'baslangic', ((((now() at time zone 'Europe/Istanbul')::date + 2) + time '10:00') at time zone 'Europe/Istanbul'),
    'usta', :uA, 'hizmetler', jsonb_build_array(:hA))), 'özel not') as qr_tamam;

-- ===== 1) DİĞER SALONUN SAHİBİ (B), A salonuna saldırır =====
reset role; select set_config('request.jwt.claim.sub', :sB, false); set role authenticated;
select pg_temp.sifir_bekle('B, A salonunun randevularını okuyamaz', $q$select count(*) from public.randevular where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$q$);
select pg_temp.sifir_bekle('B, A salonunun randevu hizmetlerini okuyamaz', $q$select count(*) from public.randevu_hizmetleri$q$);
select pg_temp.sifir_bekle('B, A salonunun davetlerini okuyamaz', $q$select count(*) from public.usta_davetleri where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$q$);
select pg_temp.sifir_bekle('B, başkasının profilini okuyamaz', $q$select count(*) from public.profiller where id <> '22222222-2222-2222-2222-222222222222'$q$);
select pg_temp.sifir_bekle('B, A salonunun takvimini çekemez', $q$select count(*) from public.salon_takvimi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now(), now() + interval '10 days')$q$);
select pg_temp.sifir_bekle('B, A hizmet fiyatını değiştiremez', $q$with u as (update public.hizmetler set fiyat = 1 where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1) select count(*) from u$q$);
select pg_temp.sifir_bekle('B, A salon adını değiştiremez', $q$with u as (update public.salonlar set ad = 'Hacklendi' where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1) select count(*) from u$q$);
select pg_temp.sifir_bekle('B, A ustalarını kapatamaz', $q$with u as (update public.ustalar set aktif = false where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1) select count(*) from u$q$);
select pg_temp.sifir_bekle('B, A randevusunu iptal edemez', $q$with u as (update public.randevular set durum = 'iptal' where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1) select count(*) from u$q$);
select pg_temp.sifir_bekle('B, A salonunu silemez', $q$with u as (delete from public.salonlar where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1) select count(*) from u$q$);
select pg_temp.sifir_bekle('B, A hizmetlerini silemez', $q$with u as (delete from public.hizmetler where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' returning 1) select count(*) from u$q$);
select pg_temp.hata_bekle('B, A salonuna hizmet ekleyemez', $q$insert into public.hizmetler (salon_id, ad, sure_dk, fiyat, kategori, sira) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'x', 10, 1, 'sac', 9)$q$);
select pg_temp.hata_bekle('B, A salonuna usta ekleyemez', $q$insert into public.ustalar (salon_id, ad, sira) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'x', 9)$q$);
select pg_temp.hata_bekle('B, A salonuna randevu yazamaz', $q$insert into public.randevular (salon_id, usta_id, tur, aralik) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1111111-1111-1111-1111-111111111111', 'blok', tstzrange(now() + interval '5 days', now() + interval '5 days 1 hour'))$q$);
select pg_temp.hata_bekle('B, A ustası için davet kodu üretemez', $q$select public.usta_davet_kodu_olustur('a1111111-1111-1111-1111-111111111111')$q$);
select pg_temp.hata_bekle('B, A ustasına blok koyamaz', $q$select public.blok_ekle('a1111111-1111-1111-1111-111111111111', now() + interval '6 days', now() + interval '6 days 1 hour')$q$);
select pg_temp.hata_bekle('B, A salonuna dükkan randevusu yazamaz', $q$select public.dukkan_randevusu('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1111111-1111-1111-1111-111111111111', now() + interval '7 days', array['c1111111-1111-1111-1111-111111111111']::uuid[], 'x', '05320000000')$q$);
select pg_temp.hata_bekle('B, A hizmet sırasını değiştiremez', $q$select public.hizmet_sirala('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', array['c1111111-1111-1111-1111-111111111111']::uuid[])$q$);
select pg_temp.hata_bekle('B, A ustasının saatlerini değiştiremez', $q$select public.usta_saatlerini_kaydet('a1111111-1111-1111-1111-111111111111', '[]'::jsonb)$q$);
select pg_temp.hata_bekle('B, A ustasının hizmetlerini değiştiremez', $q$select public.usta_hizmetlerini_kaydet('a1111111-1111-1111-1111-111111111111', array[]::uuid[])$q$);
select pg_temp.hata_bekle('B, A ustasının hesabını ayıramaz', $q$select public.usta_hesabini_ayir('a1111111-1111-1111-1111-111111111111')$q$);
-- (salon_hazirligi yalnız herkese açık sayıları verir: hizmet/usta adedi, kapak var mı; sızıntı yok)
select pg_temp.hata_bekle('B, A salonunu başkasının adına açamaz', $q$insert into public.salonlar (sahip_id, kisa_ad, ad) values ('11111111-1111-1111-1111-111111111111', 'calinti', 'x')$q$);

-- ===== 2) YABANCI HESAP (hiç salonu yok) =====
reset role; select set_config('request.jwt.claim.sub', :yab, false); set role authenticated;
select pg_temp.sifir_bekle('yabancı hiç randevu göremez', $q$select count(*) from public.randevular$q$);
select pg_temp.sifir_bekle('yabancı başkasının profilini göremez', $q$select count(*) from public.profiller where id <> '33333333-3333-3333-3333-333333333333'$q$);
select pg_temp.hata_bekle('yabancı davet kodunu tahminle ekibe giremez', $q$select public.usta_davetini_kabul_et('AAAA-AAAA')$q$);

-- ===== 3) ZİYARETÇİ (anon) =====
reset role; select set_config('request.jwt.claim.sub', '', false); set role anon;
select pg_temp.sifir_bekle('anon randevu göremez', $q$select count(*) from public.randevular$q$);
select pg_temp.sifir_bekle('anon randevu hizmetlerini göremez', $q$select count(*) from public.randevu_hizmetleri$q$);
select pg_temp.sifir_bekle('anon profil göremez', $q$select count(*) from public.profiller$q$);
select pg_temp.hata_bekle('anon usta davetlerini okuyamaz', $q$select count(*) from public.usta_davetleri$q$);
select pg_temp.hata_bekle('anon bildirim jetonlarını okuyamaz', $q$select count(*) from public.bildirim_jetonlari$q$);
select pg_temp.hata_bekle('anon gönderilen bildirimleri okuyamaz', $q$select count(*) from public.gonderilen_bildirimler$q$);
select pg_temp.hata_bekle('anon randevu ekleyemez', $q$insert into public.randevular (salon_id, usta_id, aralik) values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1111111-1111-1111-1111-111111111111', tstzrange(now() + interval '9 days', now() + interval '9 days 1 hour'))$q$);
select pg_temp.hata_bekle('anon randevu değiştiremez', $q$update public.randevular set durum = 'iptal'$q$);
select pg_temp.hata_bekle('anon salon değiştiremez', $q$update public.salonlar set ad = 'x'$q$);
select pg_temp.hata_bekle('anon hizmet silemez', $q$delete from public.hizmetler$q$);
select pg_temp.hata_bekle('anon hesabimi_sil çağıramaz', $q$select public.hesabimi_sil(true)$q$);
select pg_temp.hata_bekle('anon randevu_iptal çağıramaz', $q$select public.randevu_iptal(gen_random_uuid())$q$);
select pg_temp.hata_bekle('anon blok_ekle çağıramaz', $q$select public.blok_ekle('a1111111-1111-1111-1111-111111111111', now(), now() + interval '1 hour')$q$);
select pg_temp.hata_bekle('anon salon_takvimi çağıramaz', $q$select * from public.salon_takvimi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now(), now() + interval '10 days')$q$);
select pg_temp.hata_bekle('anon randevu_al (girişli) çağıramaz', $q$select public.randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', now() + interval '3 days', array['c1111111-1111-1111-1111-111111111111']::uuid[])$q$);
select pg_temp.hata_bekle('anon yorum_yaz çağıramaz', $q$select public.yorum_yaz(gen_random_uuid(), 5, 'x')$q$);
select pg_temp.hata_bekle('anon yayında olmayan/olmayan salona randevu alamaz', $q$select public.qr_sepet_randevu_al(gen_random_uuid(), 'Deneme', '05321112255', '[{"kisi":"Deneme"}]'::jsonb)$q$);
select pg_temp.sifir_bekle('anon eski qr_randevu_al fonksiyonunu çağıramaz', $q$select case when has_function_privilege('anon', 'public.qr_randevu_al(uuid,timestamptz,uuid[],uuid,text,text,text)', 'execute') then 1 else 0 end$q$);
-- Ad alanına SQL yazmak hiçbir şey bozmaz (parametre olarak işlenir)
select pg_temp.hata_bekle('SQL enjeksiyonlu ad yalnız doğrulamaya takılır', $q$select public.qr_sepet_randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', $$x'); drop table public.salonlar;--$$, '05321112244', '[]'::jsonb)$q$);
do $$ begin
  if (select count(*) from public.salonlar) <> 2 then raise exception 'TEST HATASI: salon tablosu bozuldu'; end if;
  raise notice 'GEÇTİ: SQL enjeksiyonu denemesi tabloya dokunamadı';
end $$;

-- ===== 4) Kimlik alanları ziyaretçiden gizli; randevu sayfasının kullandığı alanlar açık =====
select pg_temp.hata_bekle('anon salonlar.sahip_id okuyamaz', $q$select sahip_id from public.salonlar$q$);
select pg_temp.hata_bekle('anon salonlar için select * yapamaz', $q$select * from public.salonlar$q$);
select pg_temp.hata_bekle('anon ustalar.kullanici_id okuyamaz', $q$select kullanici_id from public.ustalar$q$);
select pg_temp.hata_bekle('anon galeri.musteri_id okuyamaz', $q$select musteri_id from public.galeri$q$);
select pg_temp.hata_bekle('anon yorumlar.musteri_id okuyamaz', $q$select musteri_id from public.yorumlar$q$);
do $$ begin
  -- Randevu sayfasının tam sorguları
  perform id, ad, aciklama, telefon, adres, ilce, sehir, ucretsiz_iptal_dk from public.salonlar where kisa_ad = 'salon-a' and yayinda = true;
  if (select count(*) from public.salonlar where kisa_ad = 'salon-a' and yayinda = true) <> 1 then raise exception 'TEST HATASI: randevu sayfası salonu bulamıyor'; end if;
  perform id, ad, sure_dk, fiyat, kategori, hedef from public.hizmetler where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and aktif = true order by sira;
  perform id, ad, unvan from public.ustalar where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' and aktif = true order by sira;
  perform usta_id, hizmet_id from public.usta_hizmet where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  perform count(*) from public.musait_saatler('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 3, array['c1111111-1111-1111-1111-111111111111']::uuid[]);
  perform count(*) from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 3,
    '[{"hizmetler":["c1111111-1111-1111-1111-111111111111"],"usta":null}]'::jsonb);
  perform public.salon_saatleri('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  raise notice 'GEÇTİ: randevu sayfasının bütün sorguları (sütun kısıtından sonra da) çalışıyor';
end $$;
reset role; select set_config('request.jwt.claim.sub', :sA, false); set role authenticated;
do $$ begin
  if (select sahip_id from public.salonlar where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') is null then raise exception 'TEST HATASI: sahip kendi sahip_id alanını okuyamıyor'; end if;
  raise notice 'GEÇTİ: salon sahibi kendi kayıtlarını tam görüyor';
end $$;

-- ===== 5) HIZ SINIRI: sahte telefonlarla art arda QR randevusu =====
reset role; set role anon;
do $$
declare i int; basarili int := 0; son text;
begin
  for i in 1..40 loop
    begin
      perform public.qr_sepet_randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Sahte ' || i, '0532' || lpad((7000000 + i)::text, 7, '0'),
        jsonb_build_array(jsonb_build_object('kisi', 'Sahte ' || i, 'baslangic',
          ((((now() at time zone 'Europe/Istanbul')::date + 3 + (i / 16)) + time '09:00' + ((i % 16) * interval '30 minutes')) at time zone 'Europe/Istanbul'),
          'usta', 'a1111111-1111-1111-1111-111111111111', 'hizmetler', jsonb_build_array('c1111111-1111-1111-1111-111111111111'))));
      basarili := basarili + 1;
    exception when sqlstate '53400' then son := sqlerrm;
    end;
  end loop;
  if basarili >= 40 then raise exception 'TEST HATASI: hız sınırı yok, 40 sahte randevu kabul edildi'; end if;
  if basarili < 25 then raise exception 'TEST HATASI: hız sınırı gereğinden sıkı (% kabul)', basarili; end if;
  raise notice 'GEÇTİ: hız sınırı sahte randevuları durdurdu (% kabul edildi, sonra: %)', basarili, left(son, 50);
end $$;
-- Diğer salon etkilenmez
reset role; select set_config('request.jwt.claim.sub', '', false); set role anon;
select public.qr_sepet_randevu_al(:salB, 'Normal Müşteri', '05329998877',
  jsonb_build_array(jsonb_build_object('kisi', 'Normal Müşteri',
    'baslangic', ((((now() at time zone 'Europe/Istanbul')::date + 2) + time '11:00') at time zone 'Europe/Istanbul'),
    'usta', :uB, 'hizmetler', jsonb_build_array(:hB))));
\echo GEÇTİ: hız sınırı yalnız saldırı altındaki salonu etkiler, diğer salon randevu alabiliyor
reset role;
\echo TÜM GÜVENLİK DENEMELERİ GEÇTİ
