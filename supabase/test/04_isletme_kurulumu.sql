-- 20. adım: işletme kurulumu testleri (temiz veriyle).
\set ON_ERROR_STOP 1
\pset footer off
set client_min_messages = notice;

\set sahip    '''11111111-1111-1111-1111-111111111111'''
\set ustaK    '''22222222-2222-2222-2222-222222222222'''
\set mA       '''33333333-3333-3333-3333-333333333333'''
\set yabanci  '''55555555-5555-5555-5555-555555555555'''
\set salon    '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''
\set salon2   '''aaaaaaaa-0000-0000-0000-000000000002'''
\set u1       '''b1111111-1111-1111-1111-111111111111'''
\set u2       '''b2222222-2222-2222-2222-222222222222'''
\set u3       '''b3333333-3333-3333-3333-333333333333'''
\set h1       '''c1111111-1111-1111-1111-111111111111'''
\set h2       '''c2222222-2222-2222-2222-222222222222'''
\set h3       '''c3333333-3333-3333-3333-333333333333'''
\set hx       '''c9999999-9999-9999-9999-999999999999'''

insert into auth.users (id, email, raw_user_meta_data) values
  (:sahip, 'sahip@test', '{"ad_soyad": "Ahmet Şahin"}'),
  (:ustaK, 'usta@test', '{"ad_soyad": "Mehmet Usta"}'),
  (:mA, 'a@test', '{"ad_soyad": "Ali Kaya"}'),
  (:yabanci, 'y@test', '{"ad_soyad": "Başka Salon"}');

-- Başka bir salon ve hizmeti (karışmaması gereken kayıtlar)
reset role; select set_config('request.jwt.claim.sub', :yabanci, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda) values (:salon2, :yabanci, 'baska-salon', 'Başka Salon', true);
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat) values (:hx, :salon2, 'Başka hizmet', 30, 100);

reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda, ilce, sehir)
values (:salon, :sahip, 'maison-ahmet', 'Maison Ahmet', false, 'Sancaktepe', 'İstanbul');

-- 1. Hesap bağlama: sahip kendini bağlar, başkasını doğrudan bağlayamaz.
insert into public.ustalar (id, salon_id, kullanici_id, ad, sira) values (:u1, :salon, :sahip, 'Ahmet', 1);
do $$ begin
  insert into public.ustalar (salon_id, kullanici_id, ad)
  values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'Mehmet');
  raise exception 'TEST HATASI: başkasının hesabı doğrudan bağlandı';
exception when insufficient_privilege then raise notice 'GEÇTİ: sahip kendini bağlar, başkasını yalnız davetle';
end $$;
insert into public.ustalar (id, salon_id, ad, sira, unvan, uzmanlik) values
  (:u2, :salon, 'Mehmet', 2, 'Usta', array['Fade', 'Sakal']),
  (:u3, :salon, 'Can', 3, 'Kalfa', '{}');
do $$ begin
  update public.ustalar set kullanici_id = '22222222-2222-2222-2222-222222222222'
  where id = 'b2222222-2222-2222-2222-222222222222';
  raise exception 'TEST HATASI: güncellemeyle başkası bağlandı';
exception when insufficient_privilege then raise notice 'GEÇTİ: güncellemeyle de başkası bağlanamaz';
end $$;

-- 2. Hizmetler ve sıralama
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat, kategori, sira) values
  (:h1, :salon, 'Saç kesimi', 30, 400, 'sac', 1),
  (:h2, :salon, 'Sakal', 20, 250, 'sakal', 2),
  (:h3, :salon, 'Çocuk saç kesimi', 20, 300, 'cocuk', 3);
select public.hizmet_sirala(:salon, array[:h3, :h1, :hx, :h2]::uuid[]);
do $$ begin
  if (select string_agg(ad, ',' order by sira) from public.hizmetler
      where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 'Çocuk saç kesimi,Saç kesimi,Sakal'
  then raise exception 'TEST HATASI: hizmet sırası'; end if;
  if (select sira from public.hizmetler where id = 'c9999999-9999-9999-9999-999999999999') <> 0
  then raise exception 'TEST HATASI: başka salonun hizmeti sıralandı'; end if;
  raise notice 'GEÇTİ: hizmetler sürükle-bırak sırasına dizildi, başka salonunkine dokunulmadı';
end $$;
select public.usta_sirala(:salon, array[:u3, :u2, :u1]::uuid[]);
do $$ begin
  if (select string_agg(ad, ',' order by sira) from public.ustalar
      where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') <> 'Can,Mehmet,Ahmet'
  then raise exception 'TEST HATASI: usta sırası'; end if;
  raise notice 'GEÇTİ: ekip sıralandı';
end $$;

-- 3. Çalışma saatleri
select public.usta_saatlerini_kaydet(:u1, '[
  {"gun": 1, "baslangic": "09:00", "bitis": "13:00"},
  {"gun": 1, "baslangic": "14:00", "bitis": "20:00"},
  {"gun": 2, "baslangic": "10:00", "bitis": "18:00"},
  {"gun": 6, "baslangic": "12:00", "bitis": "24:00"}
]'::jsonb);
do $$ begin
  if (select count(*) from public.calisma_saatleri where usta_id = 'b1111111-1111-1111-1111-111111111111') <> 4
  then raise exception 'TEST HATASI: saatler yazılmadı'; end if;
  raise notice 'GEÇTİ: haftalık saatler yazıldı (öğle arası ve gece 24:00 dahil)';
end $$;
do $$ begin
  perform public.usta_saatlerini_kaydet('b1111111-1111-1111-1111-111111111111',
    '[{"gun": 1, "baslangic": "09:00", "bitis": "13:00"}, {"gun": 1, "baslangic": "12:00", "bitis": "15:00"}]');
  raise exception 'TEST HATASI: çakışan aralık kabul edildi';
exception when invalid_parameter_value then raise notice 'GEÇTİ: çakışan aralık reddedildi (%)', sqlerrm;
end $$;
do $$ begin
  perform public.usta_saatlerini_kaydet('b1111111-1111-1111-1111-111111111111',
    '[{"gun": 8, "baslangic": "09:00", "bitis": "13:00"}]');
  raise exception 'TEST HATASI: 8. gün kabul edildi';
exception when invalid_parameter_value then raise notice 'GEÇTİ: geçersiz gün reddedildi';
end $$;
do $$ begin
  perform public.usta_saatlerini_kaydet('b1111111-1111-1111-1111-111111111111',
    '[{"gun": 3, "baslangic": "18:00", "bitis": "09:00"}]');
  raise exception 'TEST HATASI: ters aralık kabul edildi';
exception when invalid_parameter_value then raise notice 'GEÇTİ: bitişi başlangıçtan önce olan aralık reddedildi';
end $$;
do $$ begin
  perform public.usta_saatlerini_kaydet('b1111111-1111-1111-1111-111111111111', '[
    {"gun": 4, "baslangic": "08:00", "bitis": "09:00"}, {"gun": 4, "baslangic": "10:00", "bitis": "11:00"},
    {"gun": 4, "baslangic": "12:00", "bitis": "13:00"}, {"gun": 4, "baslangic": "14:00", "bitis": "15:00"},
    {"gun": 4, "baslangic": "16:00", "bitis": "17:00"}]');
  raise exception 'TEST HATASI: 5 aralık kabul edildi';
exception when invalid_parameter_value then raise notice 'GEÇTİ: bir güne en çok 4 aralık';
end $$;
do $$ begin
  if (select count(*) from public.calisma_saatleri where usta_id = 'b1111111-1111-1111-1111-111111111111') <> 4
  then raise exception 'TEST HATASI: reddedilen kayıt eski saatleri bozdu'; end if;
  raise notice 'GEÇTİ: reddedilen kayıt eski saatlere dokunmadı';
end $$;
select public.usta_saatlerini_kaydet(:u2, '[
  {"gun": 1, "baslangic": "12:00", "bitis": "15:00"},
  {"gun": 1, "baslangic": "20:00", "bitis": "22:00"}
]'::jsonb);
select public.usta_saatlerini_kaydet(:u3, '[{"gun": 3, "baslangic": "10:00", "bitis": "16:00"}]'::jsonb);
update public.ustalar set aktif = false where id = :u3;

-- 4. Ustanın yaptığı hizmetler
select public.usta_hizmetlerini_kaydet(:u2, array[:h1, :h2, :hx]::uuid[]);
do $$ begin
  if (select count(*) from public.usta_hizmet where usta_id = 'b2222222-2222-2222-2222-222222222222') <> 2
  then raise exception 'TEST HATASI: usta hizmetleri'; end if;
  raise notice 'GEÇTİ: ustanın hizmetleri yazıldı, başka salonun hizmeti alınmadı';
end $$;
select public.usta_hizmetlerini_kaydet(:u2, '{}'::uuid[]);
do $$ begin
  if exists (select 1 from public.usta_hizmet where usta_id = 'b2222222-2222-2222-2222-222222222222')
  then raise exception 'TEST HATASI: boş liste temizlemedi'; end if;
  raise notice 'GEÇTİ: boş liste = bütün hizmetler';
end $$;

-- 5. Hazırlık listesi (yayında değil, kapak yok)
do $$ declare v jsonb := public.salon_hazirligi('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'); begin
  if (v ->> 'hizmet')::int <> 3 or (v ->> 'usta')::int <> 2 or (v ->> 'saatli_usta')::int <> 2
     or (v ->> 'kapak')::boolean or (v ->> 'yayinda')::boolean or (v ->> 'aciklama')::boolean
  then raise exception 'TEST HATASI: hazırlık %', v; end if;
  raise notice 'GEÇTİ: hazırlık listesi sayıları doğru (%)', v;
end $$;

-- 6. Yabancı salon sahibi hiçbirini yapamaz.
reset role; select set_config('request.jwt.claim.sub', :yabanci, false); set role authenticated;
do $$ begin
  perform public.hizmet_sirala('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', array['c1111111-1111-1111-1111-111111111111']::uuid[]);
  raise exception 'TEST HATASI: yabancı sıraladı';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.usta_saatlerini_kaydet('b1111111-1111-1111-1111-111111111111', '[]');
  raise exception 'TEST HATASI: yabancı saat yazdı';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.usta_hizmetlerini_kaydet('b1111111-1111-1111-1111-111111111111', '{}');
  raise exception 'TEST HATASI: yabancı hizmet yazdı';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.usta_davet_kodu_olustur('b2222222-2222-2222-2222-222222222222');
  raise exception 'TEST HATASI: yabancı davet oluşturdu';
exception when insufficient_privilege then null;
end $$;
reset role;
do $$ begin
  if (select count(*) from public.calisma_saatleri where usta_id = 'b1111111-1111-1111-1111-111111111111') <> 4
  then raise exception 'TEST HATASI: yabancı saatleri sildi'; end if;
  raise notice 'GEÇTİ: başka salonun sahibi sıralayamaz, saat ve hizmet yazamaz, davet oluşturamaz';
end $$;

-- 7. Davet kodu
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select set_config('test.kod', public.usta_davet_kodu_olustur(:u2), false) as kod \gset
do $$ declare k text := current_setting('test.kod'); begin
  if k !~ '^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$' then raise exception 'TEST HATASI: kod biçimi %', k; end if;
  if exists (select 1 from public.usta_davetleri where kod_ozeti ilike '%' || replace(k, '-', '') || '%')
  then raise exception 'TEST HATASI: kod açık saklanıyor'; end if;
  if (select count(*) from public.usta_davetleri) <> 1 then raise exception 'TEST HATASI: sahip daveti görmüyor'; end if;
  raise notice 'GEÇTİ: davet kodu üretildi (ABCD-EFGH biçimi), yalnız özeti saklanıyor';
end $$;
do $$ begin
  perform public.usta_davet_kodu_olustur('b1111111-1111-1111-1111-111111111111');
  raise exception 'TEST HATASI: bağlı ustaya davet oluşturuldu';
exception when raise_exception then raise notice 'GEÇTİ: hesabı bağlı ustaya davet oluşturulmaz';
end $$;

reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
do $$ begin
  if exists (select 1 from public.usta_davetleri) then raise exception 'TEST HATASI: müşteri daveti gördü'; end if;
  raise notice 'GEÇTİ: müşteri davetleri göremez';
end $$;
do $$ begin
  perform public.usta_davetini_kabul_et('ZZZZ-ZZZZ');
  raise exception 'TEST HATASI: yanlış kod kabul edildi';
exception when no_data_found then raise notice 'GEÇTİ: yanlış kod reddedildi';
end $$;

reset role; select set_config('request.jwt.claim.sub', :ustaK, false); set role authenticated;
select set_config('test.katildigi', public.usta_davetini_kabul_et(lower(replace(:'kod', '-', ' ')))::text, false) as katildigi \gset
do $$ begin
  if current_setting('test.katildigi') <> 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' then raise exception 'TEST HATASI: katılınan salon'; end if;
  if (select kullanici_id from public.ustalar where id = 'b2222222-2222-2222-2222-222222222222')
     is distinct from '22222222-2222-2222-2222-222222222222'
  then raise exception 'TEST HATASI: usta bağlanmadı'; end if;
  if (select count(*) from public.ustalar where salon_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') < 2
  then raise exception 'TEST HATASI: usta ekibi görmüyor'; end if;
  raise notice 'GEÇTİ: usta kodu (küçük harf, boşluklu) girip ekibe katıldı ve salonu görüyor';
end $$;
do $$ begin
  perform public.usta_davetini_kabul_et('x');
  raise exception 'TEST HATASI: ikinci kullanım';
exception when no_data_found then raise notice 'GEÇTİ: kod tek kullanımlık';
end $$;
reset role;
do $$ begin
  if exists (select 1 from public.usta_davetleri) then raise exception 'TEST HATASI: kullanılan davet silinmedi'; end if;
end $$;

-- Süresi dolan kod
select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select set_config('test.kod2', public.usta_davet_kodu_olustur(:u3), false) as kod2 \gset
reset role;
update public.usta_davetleri set bitis = now() - interval '1 minute';
select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
do $$ begin
  perform public.usta_davetini_kabul_et(current_setting('test.kod2'));
  raise exception 'TEST HATASI: süresi dolan kod kabul edildi';
exception when no_data_found then raise notice 'GEÇTİ: süresi dolan kod reddedildi';
end $$;

-- Hesap bağlantısını kaldırma: usta kendisi ayrılır, müşteri yapamaz.
do $$ begin
  perform public.usta_hesabini_ayir('b2222222-2222-2222-2222-222222222222');
  raise exception 'TEST HATASI: müşteri bağlantıyı kaldırdı';
exception when insufficient_privilege then null;
end $$;
reset role; select set_config('request.jwt.claim.sub', :ustaK, false); set role authenticated;
select public.usta_hesabini_ayir(:u2);
reset role;
do $$ begin
  if (select kullanici_id from public.ustalar where id = 'b2222222-2222-2222-2222-222222222222') is not null
  then raise exception 'TEST HATASI: ayrılamadı'; end if;
  raise notice 'GEÇTİ: usta ekipten ayrılabilir, müşteri başkasını ayıramaz';
end $$;

-- 8. Vitrin saatleri: aktif ustaların aralıkları gün gün birleşir; yayında değilken ziyaretçi görmez.
set role anon; select set_config('request.jwt.claim.sub', '', false);
do $$ begin
  if jsonb_array_length(public.salon_saatleri('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') -> 'saatler') <> 0
  then raise exception 'TEST HATASI: yayında olmayan salonun saatleri göründü'; end if;
  raise notice 'GEÇTİ: yayında olmayan salonun saatleri ziyaretçiye görünmez';
end $$;
reset role;
update public.salonlar set yayinda = true where id = :salon;
set role anon;
do $$ declare v jsonb := public.salon_saatleri('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'); begin
  if v -> 'saatler' <> '[
      {"gun": 1, "baslangic": "09:00", "bitis": "22:00"},
      {"gun": 2, "baslangic": "10:00", "bitis": "18:00"},
      {"gun": 6, "baslangic": "12:00", "bitis": "24:00"}]'::jsonb
  then raise exception 'TEST HATASI: birleşik saatler %', v -> 'saatler'; end if;
  if v ->> 'yerel_simdi' is null then raise exception 'TEST HATASI: yerel saat yok'; end if;
  raise notice 'GEÇTİ: vitrin saatleri birleşti, pasif usta sayılmadı (%), yerel saat %', v -> 'saatler', v ->> 'yerel_simdi';
end $$;
reset role;

-- 9. Boş saatler yeni kayıtlarla çalışıyor (gelecek pazartesi, Ahmet 09–13 ve 14–20).
do $$ declare n int; v_gun date := current_date + (8 - extract(isodow from current_date)::int); begin
  -- 09:00–12:30 arası 15 başlangıç + 14:00–19:30 arası 23 başlangıç (30 dakikalık hizmet, 15 dakika adım)
  select count(*) into n
  from public.bos_saatler('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', v_gun, 30, 'b1111111-1111-1111-1111-111111111111');
  if n <> 38 then raise exception 'TEST HATASI: boş saat sayısı % (38 beklenirdi)', n; end if;
  raise notice 'GEÇTİ: boş saatler yeni çalışma saatlerinden hesaplanıyor (% aralık)', n;
end $$;

-- 10. Anonim ziyaretçi yönetim fonksiyonlarını çağıramaz.
set role anon;
do $$ begin
  perform public.usta_davetini_kabul_et('ABCD-EFGH');
  raise exception 'TEST HATASI: anonim çağırdı';
exception when insufficient_privilege then raise notice 'GEÇTİ: anonim ziyaretçi davet ve düzenleme fonksiyonlarını çağıramaz';
end $$;
reset role;

do $$ begin raise notice 'TÜM TESTLER BİTTİ'; end $$;
