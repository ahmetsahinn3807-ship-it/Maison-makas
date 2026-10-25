-- Uygulama kapalıyken bildirim: jeton kaydı ve olay hazırlığı.
\set ON_ERROR_STOP 1
\pset footer off
set client_min_messages = notice;

\set sahip  '''11111111-1111-1111-1111-111111111111'''
\set ustaK  '''22222222-2222-2222-2222-222222222222'''
\set mA     '''33333333-3333-3333-3333-333333333333'''
\set yabanci '''44444444-4444-4444-4444-444444444444'''
\set salon  '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''
\set u1     '''b1111111-1111-1111-1111-111111111111'''
\set u2     '''b2222222-2222-2222-2222-222222222222'''
\set r1     '''d1111111-1111-1111-1111-111111111111'''
\set r2     '''d2222222-2222-2222-2222-222222222222'''
\set r3     '''d3333333-3333-3333-3333-333333333333'''

insert into auth.users (id, email, raw_user_meta_data) values
  (:sahip, 'sahip@test', '{"ad_soyad": "Ahmet Şahin"}'),
  (:ustaK, 'usta@test', '{"ad_soyad": "Mehmet Usta"}'),
  (:mA, 'a@test', '{"ad_soyad": "Ali Kaya"}'),
  (:yabanci, 'y@test', '{"ad_soyad": "Yabancı"}');

insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda) values (:salon, :sahip, 'maison-ahmet', 'Maison Ahmet', true);
insert into public.ustalar (id, salon_id, kullanici_id, ad, sira) values (:u1, :salon, :sahip, 'Ahmet', 1);
insert into public.ustalar (id, salon_id, kullanici_id, ad, sira) values (:u2, :salon, :ustaK, 'Mehmet', 2);
insert into public.randevular (id, salon_id, usta_id, musteri_id, aralik, kaynak) values
  (:r1, :salon, :u2, :mA, tstzrange(now() + interval '2 days', now() + interval '2 days 30 minutes'), 'uygulama'),
  (:r2, :salon, :u2, :mA, tstzrange(now() + interval '3 days', now() + interval '3 days 30 minutes'), 'uygulama'),
  (:r3, :salon, :u1, null, tstzrange(now() + interval '4 days', now() + interval '4 days 30 minutes'), 'dukkan');
insert into public.randevu_hizmetleri (randevu_id, ad, sure_dk, fiyat) values
  (:r1, 'Saç kesimi', 30, 400), (:r1, 'Sakal', 20, 250);

-- Jetonlar: sahip ve usta Makas Pro'da, müşteri Maison Makas'ta (İngilizce) ve Makas Pro'da.
select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
select public.bildirim_jetonu_kaydet('jeton-sahip-pro-000000000001', 'pro', 'android', 'tr');
reset role; select set_config('request.jwt.claim.sub', :ustaK, false); set role authenticated;
select public.bildirim_jetonu_kaydet('jeton-usta-pro-0000000000001', 'pro', 'android', 'tr');
reset role; select set_config('request.jwt.claim.sub', :mA, false); set role authenticated;
select public.bildirim_jetonu_kaydet('jeton-musteri-00000000000001', 'musteri', 'android', 'en');
select public.bildirim_jetonu_kaydet('jeton-musteri-00000000000001', 'musteri', 'android', 'en');
reset role;

do $$ begin
  if (select count(*) from public.bildirim_jetonlari) <> 3 then raise exception 'TEST HATASI: jeton sayısı'; end if;
  raise notice 'GEÇTİ: jetonlar kaydedildi, aynı jeton iki kez yazılınca tek satır kalır';
end $$;

-- Tablolara doğrudan erişim yok.
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
set role authenticated;
do $$ begin
  begin
    perform count(*) from public.bildirim_jetonlari;
    raise exception 'TEST HATASI: jetonlar doğrudan okundu';
  exception when insufficient_privilege then null;
  end;
  raise notice 'GEÇTİ: jeton tablosu doğrudan okunamaz';
end $$;

-- 1. Yeni randevu: müşteri çağırır, salon sahibine ve ustaya gider.
do $$ declare s jsonb; begin
  s := public.randevu_bildirimi_hazirla('d1111111-1111-1111-1111-111111111111');
  if s->>'olay' <> 'yeni' then raise exception 'TEST HATASI: olay %', s->>'olay'; end if;
  if jsonb_array_length(s->'alicilar') <> 2 then raise exception 'TEST HATASI: alıcılar %', s->'alicilar'; end if;
  if (s->'alicilar')::text like '%jeton-musteri%' then raise exception 'TEST HATASI: müşteriye de gitti'; end if;
  if s->>'musteri' <> 'Ali Kaya' or s->>'usta' <> 'Mehmet' or s->>'hizmetler' <> 'Sakal, Saç kesimi'
     or s->>'salon' <> 'Maison Ahmet' then raise exception 'TEST HATASI: içerik %', s; end if;
  if s->>'baslangic' !~ '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$' then raise exception 'TEST HATASI: saat %', s->>'baslangic'; end if;
  raise notice 'GEÇTİ: yeni randevu salon sahibine ve ustaya (Makas Pro) hazırlanır';
  if public.randevu_bildirimi_hazirla('d1111111-1111-1111-1111-111111111111') is not null
  then raise exception 'TEST HATASI: ikinci kez hazırlandı'; end if;
  raise notice 'GEÇTİ: aynı olay ikinci kez gönderilmez';
end $$;

-- 2. Yabancı çağıramaz.
reset role; select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
set role authenticated;
do $$ begin
  begin
    perform public.randevu_bildirimi_hazirla('d2222222-2222-2222-2222-222222222222');
    raise exception 'TEST HATASI: yabancı hazırladı';
  exception when insufficient_privilege then null;
  end;
  raise notice 'GEÇTİ: randevuyla ilgisi olmayan hesap bildirim hazırlayamaz';
end $$;

-- 3. Müşteri iptal eder → salona; 4. salon iptal eder → müşteriye (İngilizce jeton).
reset role; select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', false);
set role authenticated;
select public.randevu_iptal('d1111111-1111-1111-1111-111111111111');
do $$ declare s jsonb; begin
  s := public.randevu_bildirimi_hazirla('d1111111-1111-1111-1111-111111111111');
  if s->>'olay' <> 'musteri_iptal' or jsonb_array_length(s->'alicilar') <> 2
  then raise exception 'TEST HATASI: müşteri iptali %', s; end if;
  raise notice 'GEÇTİ: müşterinin iptali salona hazırlanır';
end $$;
reset role; select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false);
set role authenticated;
select public.randevu_iptal('d2222222-2222-2222-2222-222222222222');
do $$ declare s jsonb; begin
  s := public.randevu_bildirimi_hazirla('d2222222-2222-2222-2222-222222222222');
  if s->>'olay' <> 'salon_iptal' or jsonb_array_length(s->'alicilar') <> 1
     or s->'alicilar'->0->>'jeton' <> 'jeton-musteri-00000000000001' or s->'alicilar'->0->>'dil' <> 'en'
  then raise exception 'TEST HATASI: salon iptali %', s; end if;
  raise notice 'GEÇTİ: salonun iptali müşteriye, onun dilinde hazırlanır';
  -- Dükkânda yazılan (müşterisiz) randevu için bildirim yok.
  if public.randevu_bildirimi_hazirla('d3333333-3333-3333-3333-333333333333') is not null
  then raise exception 'TEST HATASI: dükkân randevusu'; end if;
  raise notice 'GEÇTİ: kapıdan gelen müşteri için bildirim hazırlanmaz';
end $$;

-- 5. Jeton el değiştirir; başkasının jetonu silinemez; kendi jetonu silinir.
reset role; select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', false);
set role authenticated;
select public.bildirim_jetonu_sil('jeton-sahip-pro-000000000001');
select public.bildirim_jetonu_kaydet('jeton-usta-pro-0000000000001', 'pro', 'android', 'tr');
reset role;
do $$ begin
  if not exists (select 1 from public.bildirim_jetonlari where jeton = 'jeton-sahip-pro-000000000001')
  then raise exception 'TEST HATASI: başkasının jetonu silindi'; end if;
  if (select kullanici_id from public.bildirim_jetonlari where jeton = 'jeton-usta-pro-0000000000001')
     <> '44444444-4444-4444-4444-444444444444' then raise exception 'TEST HATASI: jeton el değiştirmedi'; end if;
  raise notice 'GEÇTİ: telefonda başka hesapla girilince jeton yeni hesaba geçer; başkasının jetonu silinemez';
end $$;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false); set role authenticated;
select public.bildirim_jetonu_sil('jeton-sahip-pro-000000000001');
reset role;
do $$ begin
  if exists (select 1 from public.bildirim_jetonlari where jeton = 'jeton-sahip-pro-000000000001')
  then raise exception 'TEST HATASI: kendi jetonu silinmedi'; end if;
  raise notice 'GEÇTİ: çıkışta kendi jetonu silinir';
end $$;

-- 6. Anonim çağıramaz.
set role anon; select set_config('request.jwt.claim.sub', '', false);
do $$ begin
  begin
    perform public.bildirim_jetonu_kaydet('jeton-anonim-00000000000001', 'musteri');
    raise exception 'TEST HATASI: anonim jeton kaydetti';
  exception when insufficient_privilege then null;
  end;
  raise notice 'GEÇTİ: giriş yapmamış biri jeton kaydedemez';
end $$;
reset role;

do $$ begin raise notice 'TÜM TESTLER BİTTİ'; end $$;
