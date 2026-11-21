-- Çoklu usta (her işleme ayrı usta) testleri. Temiz veriyle çalışır.
\set ON_ERROR_STOP 1
\pset footer off
set client_min_messages = notice;

\set sahip  '''11111111-1111-1111-1111-111111111111'''
\set salon  '''aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'''
\set u1     '''b1111111-1111-1111-1111-111111111111'''
\set u2     '''b2222222-2222-2222-2222-222222222222'''
\set h1     '''c1111111-1111-1111-1111-111111111111'''
\set h2     '''c2222222-2222-2222-2222-222222222222'''
\set h3     '''c3333333-3333-3333-3333-333333333333'''

insert into auth.users (id, email, raw_user_meta_data) values
  (:sahip, 'sahip@test', '{"ad_soyad": "Ahmet Şahin"}');

-- Kurulum: Ahmet (saç kesimi 30 dk, sakal 20 dk; pazartesi 09:00-13:00),
--          Mehmet (saç kesimi, boyama 60 dk; pazartesi 10:00-12:00).
reset role; select set_config('request.jwt.claim.sub', :sahip, false); set role authenticated;
insert into public.salonlar (id, sahip_id, kisa_ad, ad, yayinda) values (:salon, :sahip, 'maison-ahmet', 'Maison Ahmet', true);
insert into public.hizmetler (id, salon_id, ad, sure_dk, fiyat, sira, aktif) values
  (:h1, :salon, 'Saç kesimi', 30, 400, 1, true),
  (:h2, :salon, 'Sakal', 20, 250, 2, true),
  (:h3, :salon, 'Saç boyama', 60, 900, 3, true);
insert into public.ustalar (id, salon_id, kullanici_id, ad, sira) values (:u1, :salon, :sahip, 'Ahmet', 1);
insert into public.ustalar (id, salon_id, ad, sira) values (:u2, :salon, 'Mehmet', 2);
select public.usta_hizmetlerini_kaydet(:u1, array[:h1, :h2]::uuid[]);
select public.usta_hizmetlerini_kaydet(:u2, array[:h1, :h3]::uuid[]);
select public.usta_saatlerini_kaydet(:u1, '[{"gun": 1, "baslangic": "09:00", "bitis": "13:00"}]');
select public.usta_saatlerini_kaydet(:u2, '[{"gun": 1, "baslangic": "10:00", "bitis": "12:00"}]');
reset role;

select set_config('test.gun', (current_date + (8 - extract(isodow from current_date)::int))::text, false);

create function pg_temp.zincir(p_parcalar jsonb, p_mesgul jsonb default '[]')
returns table (saat text, ustalar text)
language sql as $$
  select to_char(z.baslangic at time zone 'Europe/Istanbul', 'HH24:MI'),
         (select string_agg(u.ad, '+' order by o.n)
            from unnest(z.usta_idler) with ordinality as o (id, n) join public.ustalar u on u.id = o.id)
  from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_setting('test.gun')::date, 1, p_parcalar, p_mesgul) z
  order by z.baslangic
$$;
create function pg_temp.saatler(p_parcalar jsonb, p_mesgul jsonb default '[]') returns text
language sql as $$ select coalesce(string_agg(saat, ',' order by saat), '') from pg_temp.zincir(p_parcalar, p_mesgul) $$;
create function pg_temp.atama(p_parcalar jsonb, p_saat text) returns text
language sql as $$ select ustalar from pg_temp.zincir(p_parcalar) where saat = p_saat $$;

set role anon; select set_config('request.jwt.claim.sub', '', false);

-- 1. Tek parça (eski davranış): saç kesimi, usta fark etmez -> iki ustanın saatleri birleşir, her saat bir kez.
do $$ declare r text; begin
  r := pg_temp.saatler('[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null}]');
  if r <> '09:00,09:15,09:30,09:45,10:00,10:15,10:30,10:45,11:00,11:15,11:30,11:45,12:00,12:15,12:30'
  then raise exception 'TEST HATASI: tek parça %', r; end if;
  if pg_temp.atama('[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null}]', '10:00') <> 'Ahmet'
  then raise exception 'TEST HATASI: fark etmez ilk ustaya (sıra) gitmeli'; end if;
  raise notice 'GEÇTİ: tek parça eski davranışla aynı';
end $$;

-- 2. Boyama Mehmet'te, ardından sakal Ahmet'te: boyama 10:00-11:00 arası başlar (60 dk), sakal hemen ardından.
do $$ declare r text; p jsonb := '[
  {"hizmetler": ["c3333333-3333-3333-3333-333333333333"], "usta": "b2222222-2222-2222-2222-222222222222"},
  {"hizmetler": ["c2222222-2222-2222-2222-222222222222"], "usta": "b1111111-1111-1111-1111-111111111111"}]';
begin
  r := pg_temp.saatler(p);
  if r <> '10:00,10:15,10:30,10:45,11:00' then raise exception 'TEST HATASI: boyama+sakal %', r; end if;
  if pg_temp.atama(p, '10:00') <> 'Mehmet+Ahmet' then raise exception 'TEST HATASI: usta sırası'; end if;
  raise notice 'GEÇTİ: boyama (Mehmet) sonra sakal (Ahmet): 5 başlangıç, usta sırası korunur';
end $$;

-- 3. Ters sıra: önce sakal (Ahmet, 20 dk), sonra boyama (Mehmet). Boyama 10:00-11:00 arası başlamalı;
--    ilk parça 15 dk adımlı, ikincisi saat dışı dakikada (10:05 gibi) başlayabilir.
do $$ declare r text; p jsonb := '[
  {"hizmetler": ["c2222222-2222-2222-2222-222222222222"], "usta": "b1111111-1111-1111-1111-111111111111"},
  {"hizmetler": ["c3333333-3333-3333-3333-333333333333"], "usta": "b2222222-2222-2222-2222-222222222222"}]';
begin
  r := pg_temp.saatler(p);
  if r <> '09:45,10:00,10:15,10:30' then raise exception 'TEST HATASI: sakal+boyama %', r; end if;
  raise notice 'GEÇTİ: sakal (Ahmet) sonra boyama (Mehmet): sıra değişince saatler değişir (09:45-10:30)';
end $$;

-- 4. Fark etmez + adı verilmiş usta: saç kesimi fark etmez ama boyama Mehmet'te -> saç kesimi Ahmet'e gider,
--    Mehmet'e değil (Mehmet boyama için ayrılmış). Saç 30 dk, sonra boyama.
do $$ declare r text; p jsonb := '[
  {"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null},
  {"hizmetler": ["c3333333-3333-3333-3333-333333333333"], "usta": "b2222222-2222-2222-2222-222222222222"}]';
begin
  r := pg_temp.saatler(p);
  if r <> '09:30,09:45,10:00,10:15,10:30' then raise exception 'TEST HATASI: fark etmez + boyama %', r; end if;
  if pg_temp.atama(p, '10:00') <> 'Ahmet+Mehmet' then raise exception 'TEST HATASI: fark etmez ayrılmış ustayı aldı'; end if;
  raise notice 'GEÇTİ: fark etmez parçası, adıyla seçilmiş ustayı almıyor';
end $$;

-- 5. Hiçbir ustanın tek başına yapamadığı iş: Ahmet boyama yapmaz -> saat yok.
do $$ begin
  if pg_temp.saatler('[{"hizmetler": ["c3333333-3333-3333-3333-333333333333"], "usta": "b1111111-1111-1111-1111-111111111111"}]') <> ''
  then raise exception 'TEST HATASI: usta yapmadığı hizmette saat verdi'; end if;
  -- Saç + boyama birlikte (tek parça, fark etmez): yalnız Mehmet ikisini yapar, 10:00-11:30 arası, 90 dk -> 10:00,10:15,10:30
  if pg_temp.saatler('[{"hizmetler": ["c1111111-1111-1111-1111-111111111111","c3333333-3333-3333-3333-333333333333"], "usta": null}]') <> '10:00,10:15,10:30'
  then raise exception 'TEST HATASI: saç+boyama tek usta'; end if;
  raise notice 'GEÇTİ: yapmadığı hizmette saat çıkmaz; birden çok hizmet tek parçada ortak ustayı bulur';
end $$;

-- 6. Sepetteki (henüz kaydedilmemiş) randevular: Mehmet 10:00-11:00 dolu iken boyama (Mehmet) ancak 11:00'de başlar.
do $$ declare r text; m jsonb := format('[{"usta": "b2222222-2222-2222-2222-222222222222", "bas": "%s", "bit": "%s"}]',
    ((current_setting('test.gun')::date + time '10:00') at time zone 'Europe/Istanbul'),
    ((current_setting('test.gun')::date + time '11:00') at time zone 'Europe/Istanbul'));
begin
  r := pg_temp.saatler('[{"hizmetler": ["c3333333-3333-3333-3333-333333333333"], "usta": "b2222222-2222-2222-2222-222222222222"}]', m);
  if r <> '11:00' then raise exception 'TEST HATASI: sepette dolu usta %', r; end if;
  -- Saç kesimi fark etmez, 10:00'da Ahmet'e düşer (Mehmet sepette dolu olsa da Ahmet boş).
  if pg_temp.atama('[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null}]', '10:00') is null
  then raise exception 'TEST HATASI: 10:00 yok'; end if;
  -- Ahmet de sepette dolu: Mehmet sepette dolu 10:00-11:00 -> fark etmez saç kesimi 10:00'da hiçbirine atanamaz
  -- (Ahmet de dolu verirsek).
  r := pg_temp.saatler('[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null}]',
    format('[{"usta": "b2222222-2222-2222-2222-222222222222", "bas": "%s", "bit": "%s"},
             {"usta": "b1111111-1111-1111-1111-111111111111", "bas": "%s", "bit": "%s"}]',
      ((current_setting('test.gun')::date + time '10:00') at time zone 'Europe/Istanbul'),
      ((current_setting('test.gun')::date + time '11:00') at time zone 'Europe/Istanbul'),
      ((current_setting('test.gun')::date + time '10:00') at time zone 'Europe/Istanbul'),
      ((current_setting('test.gun')::date + time '11:00') at time zone 'Europe/Istanbul'))::jsonb);
  -- 09:30'da başlayan 30 dk 10:00'da biter (çakışmaz); 09:45-10:45 arası iki ustada da dolu.
  if r <> '09:00,09:15,09:30,11:00,11:15,11:30,11:45,12:00,12:15,12:30'
  then raise exception 'TEST HATASI: iki usta da sepette dolu %', r; end if;
  raise notice 'GEÇTİ: sepetteki randevular ustayı dolu sayar (aile için aynı saatte farklı usta)';
end $$;

-- 7. Hatalı istekler anlaşılır hata verir.
do $$ begin
  begin perform * from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 1, '[]'::jsonb);
    raise exception 'TEST HATASI: boş liste kabul edildi';
  exception when invalid_parameter_value then null; end;
  begin perform * from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 1,
      '[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null},
        {"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null}]'::jsonb);
    raise exception 'TEST HATASI: aynı hizmet iki parçada kabul edildi';
  exception when invalid_parameter_value then null; end;
  begin perform * from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 1,
      '[{"hizmetler": ["c9999999-9999-9999-9999-999999999999"], "usta": null}]'::jsonb);
    raise exception 'TEST HATASI: olmayan hizmet kabul edildi';
  exception when invalid_parameter_value then null; end;
  begin perform * from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 1,
      '[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": "b1111111-1111-1111-1111-111111111111"},
        {"hizmetler": ["c2222222-2222-2222-2222-222222222222"], "usta": "b1111111-1111-1111-1111-111111111111"}]'::jsonb);
    raise exception 'TEST HATASI: aynı usta iki parçada kabul edildi';
  exception when invalid_parameter_value then null; end;
  begin perform * from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 1,
      '[{"hizmetler": ["zzz"], "usta": null}]'::jsonb);
    raise exception 'TEST HATASI: bozuk hizmet kimliği kabul edildi';
  exception when invalid_parameter_value then null; end;
  begin perform * from public.musait_saatler_zincir('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 1,
      '[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null}]'::jsonb, '{"a": 1}'::jsonb);
    raise exception 'TEST HATASI: bozuk sepet bilgisi kabul edildi';
  exception when invalid_parameter_value then null; end;
  raise notice 'GEÇTİ: hatalı istekler 22023 ile reddedilir';
end $$;

-- 7b. Şimdiden 30 dakikadan yakın saat listelenmez (onayda reddedilirdi).
do $$ declare n int; begin
  select count(*) into n from public.musait_saatler_zincir(
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', current_date, 3,
    '[{"hizmetler": ["c1111111-1111-1111-1111-111111111111"], "usta": null}]'::jsonb) z
  where z.baslangic < now() + interval '30 minutes';
  if n <> 0 then raise exception 'TEST HATASI: 30 dakikadan yakın saat listelendi'; end if;
  raise notice 'GEÇTİ: 30 dakikadan yakın saat listelenmez';
end $$;

-- 8. İç fonksiyonlara ziyaretçi doğrudan erişemez.
do $$ begin
  begin perform public.usta_hizmet_yapar_mi('b1111111-1111-1111-1111-111111111111', '{}'::uuid[]);
    raise exception 'TEST HATASI: iç fonksiyon açıktı';
  exception when insufficient_privilege then null; end;
  begin perform public.usta_sepette_dolu_mu(null, now(), now(), '[]'::jsonb, 0);
    raise exception 'TEST HATASI: iç fonksiyon açıktı (2)';
  exception when insufficient_privilege then null; end;
  raise notice 'GEÇTİ: iç fonksiyonlar kapalı';
end $$;

-- 9. Aynı kişi iki ustadan art arda randevu alır (sepet fonksiyonu eskisi gibi): iki kayıt, art arda saatler;
--    sonra aynı zincir o saati artık vermez.
do $$ declare n int; v_bas timestamptz := (current_setting('test.gun')::date + time '10:00') at time zone 'Europe/Istanbul'; r text;
  p jsonb := '[
  {"hizmetler": ["c3333333-3333-3333-3333-333333333333"], "usta": "b2222222-2222-2222-2222-222222222222"},
  {"hizmetler": ["c2222222-2222-2222-2222-222222222222"], "usta": "b1111111-1111-1111-1111-111111111111"}]';
begin
  n := public.qr_sepet_randevu_al('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Ahmet Y', '0532 111 22 33',
    jsonb_build_array(
      jsonb_build_object('kisi', 'Ahmet Y', 'baslangic', v_bas, 'usta', 'b2222222-2222-2222-2222-222222222222', 'hizmetler', jsonb_build_array('c3333333-3333-3333-3333-333333333333')),
      jsonb_build_object('kisi', 'Ahmet Y', 'baslangic', v_bas + interval '60 minutes', 'usta', 'b1111111-1111-1111-1111-111111111111', 'hizmetler', jsonb_build_array('c2222222-2222-2222-2222-222222222222'))));
  if n <> 2 then raise exception 'TEST HATASI: sepet % randevu yazdı', n; end if;
  r := pg_temp.saatler(p);
  -- Mehmet 10:00-11:00 doldu; boyama için yalnız 11:00 kalır (Mehmet 11:00-12:00 boş, sakal 12:00'de Ahmet'te boş).
  if r <> '11:00' then raise exception 'TEST HATASI: alınan saat hâlâ listede %', r; end if;
  raise notice 'GEÇTİ: iki ustadan art arda randevu kaydedilir, saatler boş listeden düşer (kalan: %)', r;
end $$;

reset role;
select count(*) as randevu_sayisi, string_agg(distinct u.ad, ' + ') as ustalar
from public.randevular r join public.ustalar u on u.id = r.usta_id;
