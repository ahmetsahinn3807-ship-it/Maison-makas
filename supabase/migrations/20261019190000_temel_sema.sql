-- ============================================================================
-- Maison Makas · Temel veritabanı (rehberde 15. adım)
--
-- Nasıl çalıştırılır: Supabase → SQL Editor → New query → bu metnin tamamını
-- yapıştır → Run. Boş bir projede bir kez çalıştırılır. Bir hata çıkarsa hiçbir
-- şey yarım kalmaz (tamamı tek işlem olarak geri alınır).
--
-- Kurulanlar:
--   profiller, salonlar, ustalar, hizmetler, usta_hizmet, calisma_saatleri,
--   randevular (+ takvim blokları), randevu_hizmetleri, yorumlar,
--   favori_salonlar, favori_ustalar, galeri, salon_puanlari (görünüm)
--   Çifte randevu engeli: aynı ustaya çakışan iki kayıt veritabanında yazılamaz.
--   Güvenlik: her tabloda satır düzeyi güvenlik (RLS).
--   Fonksiyonlar: bos_saatler, randevu_al, randevu_iptal, yorum_yaz, yorum_yanitla
-- ============================================================================

begin;

create extension if not exists btree_gist with schema extensions;

-- ----------------------------------------------------------------------------
-- 1. Tablolar
-- ----------------------------------------------------------------------------

create table public.profiller (
  id            uuid primary key references auth.users (id) on delete cascade,
  ad_soyad      text not null default '' check (char_length(ad_soyad) <= 80),
  telefon       text check (char_length(telefon) <= 20),
  avatar_url    text,
  kapak_url     text,
  kapak_odak_x  real not null default 0.5 check (kapak_odak_x between 0 and 1),
  kapak_odak_y  real not null default 0.5 check (kapak_odak_y between 0 and 1),
  dil           text not null default 'tr' check (dil in ('tr', 'en', 'de')),
  gorunum       jsonb not null default '{}'::jsonb,
  olusturuldu   timestamptz not null default now(),
  guncellendi   timestamptz not null default now()
);
comment on table public.profiller is 'Her kullanıcının profili: ad, telefon, profil ve kapak fotoğrafı, dil ve görünüm ayarları.';
comment on column public.profiller.gorunum is 'Palet, vurgu rengi, yazı boyutu, ana sayfa ve menü sırası, uygulama ikonu.';

create table public.salonlar (
  id                 uuid primary key default gen_random_uuid(),
  sahip_id           uuid not null references public.profiller (id) on delete restrict,
  kisa_ad            text not null unique check (kisa_ad ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'),
  ad                 text not null check (char_length(ad) between 2 and 80),
  aciklama           text check (char_length(aciklama) <= 1000),
  telefon            text check (char_length(telefon) <= 20),
  adres              text check (char_length(adres) <= 200),
  ilce               text check (char_length(ilce) <= 60),
  sehir              text check (char_length(sehir) <= 60),
  ulke               text not null default 'TR' check (ulke ~ '^[A-Z]{2}$'),
  enlem              double precision check (enlem between -90 and 90),
  boylam             double precision check (boylam between -180 and 180),
  logo_url           text,
  kapak_url          text,
  kapak_odak_x       real not null default 0.5 check (kapak_odak_x between 0 and 1),
  kapak_odak_y       real not null default 0.5 check (kapak_odak_y between 0 and 1),
  vitrin             jsonb not null default '{}'::jsonb,
  saat_dilimi        text not null default 'Europe/Istanbul',
  para_birimi        text not null default 'TRY' check (para_birimi ~ '^[A-Z]{3}$'),
  ucretsiz_iptal_dk  integer not null default 180 check (ucretsiz_iptal_dk between 0 and 10080),
  tampon_dk          integer not null default 0 check (tampon_dk between 0 and 120),
  kapora_gerekli     boolean not null default false,
  yayinda            boolean not null default false,
  dogrulandi         boolean not null default false,
  olusturuldu        timestamptz not null default now(),
  guncellendi        timestamptz not null default now()
);
comment on table public.salonlar is 'Berber ve kuaför salonları. kisa_ad web randevu sayfasının adresidir.';
comment on column public.salonlar.vitrin is 'Vitrin Stüdyosu: kapak düzeni, bölüm sırası, yazı eşleşmesi, marka rengi.';
comment on column public.salonlar.tampon_dk is 'İki randevu arasında bırakılacak temizlik/hazırlık payı (dakika).';
comment on column public.salonlar.dogrulandi is 'Yalnız platform yöneticisi değiştirebilir.';

create table public.ustalar (
  id            uuid primary key default gen_random_uuid(),
  salon_id      uuid not null references public.salonlar (id) on delete cascade,
  kullanici_id  uuid references public.profiller (id) on delete set null,
  ad            text not null check (char_length(ad) between 1 and 60),
  unvan         text check (char_length(unvan) <= 60),
  foto_url      text,
  uzmanlik      text[] not null default '{}',
  aktif         boolean not null default true,
  sira          integer not null default 0,
  olusturuldu   timestamptz not null default now(),
  guncellendi   timestamptz not null default now(),
  unique (id, salon_id),
  unique (salon_id, kullanici_id)
);
comment on table public.ustalar is 'Salon personeli. kullanici_id doluysa usta Makas Pro''ya kendi hesabıyla girer.';

create table public.hizmetler (
  id           uuid primary key default gen_random_uuid(),
  salon_id     uuid not null references public.salonlar (id) on delete cascade,
  ad           text not null check (char_length(ad) between 1 and 80),
  aciklama     text check (char_length(aciklama) <= 500),
  kategori     text not null default 'sac' check (kategori in ('sac', 'sakal', 'renk', 'bakim', 'cocuk', 'diger')),
  sure_dk      integer not null check (sure_dk between 5 and 480),
  fiyat        numeric(10, 2) not null check (fiyat >= 0),
  aktif        boolean not null default true,
  sira         integer not null default 0,
  olusturuldu  timestamptz not null default now(),
  guncellendi  timestamptz not null default now(),
  unique (id, salon_id)
);
comment on table public.hizmetler is 'Salonun hizmet menüsü: süre (dakika) ve fiyat (salonun para biriminde).';

create table public.usta_hizmet (
  salon_id   uuid not null,
  usta_id    uuid not null,
  hizmet_id  uuid not null,
  primary key (usta_id, hizmet_id),
  foreign key (usta_id, salon_id) references public.ustalar (id, salon_id) on delete cascade,
  foreign key (hizmet_id, salon_id) references public.hizmetler (id, salon_id) on delete cascade
);
comment on table public.usta_hizmet is 'Ustanın yaptığı hizmetler. Bir ustanın hiç satırı yoksa tüm hizmetleri yapar.';

create table public.calisma_saatleri (
  id         uuid primary key default gen_random_uuid(),
  salon_id   uuid not null,
  usta_id    uuid not null,
  gun        smallint not null check (gun between 1 and 7),
  baslangic  time not null,
  bitis      time not null,
  check (bitis > baslangic),
  foreign key (usta_id, salon_id) references public.ustalar (id, salon_id) on delete cascade
);
comment on table public.calisma_saatleri is 'Ustanın haftalık çalışma aralıkları (gun: 1 = Pazartesi … 7 = Pazar, salonun yerel saatiyle). Öğle arası için güne iki aralık girilir.';

create table public.randevular (
  id             uuid primary key default gen_random_uuid(),
  salon_id       uuid not null references public.salonlar (id) on delete cascade,
  usta_id        uuid not null,
  musteri_id     uuid references public.profiller (id) on delete set null,
  tur            text not null default 'randevu' check (tur in ('randevu', 'blok')),
  misafir_ad     text check (char_length(misafir_ad) <= 80),
  misafir_tel    text check (char_length(misafir_tel) <= 20),
  aralik         tstzrange not null,
  durum          text not null default 'onaylandi'
                   check (durum in ('bekliyor', 'onaylandi', 'tamamlandi', 'iptal', 'gelmedi')),
  kaynak         text not null default 'uygulama' check (kaynak in ('uygulama', 'web', 'dukkan')),
  musteri_notu   text check (char_length(musteri_notu) <= 500),
  usta_notu      text check (char_length(usta_notu) <= 1000),
  stil_foto_url  text,
  toplam_fiyat   numeric(10, 2) check (toplam_fiyat >= 0),
  iptal_eden     uuid references public.profiller (id) on delete set null,
  iptal_zamani   timestamptz,
  gec_iptal      boolean not null default false,
  olusturuldu    timestamptz not null default now(),
  guncellendi    timestamptz not null default now(),
  foreign key (usta_id, salon_id) references public.ustalar (id, salon_id),
  constraint aralik_gecerli check (
    not isempty(aralik) and lower_inc(aralik) and not upper_inc(aralik)
    and not lower_inf(aralik) and not upper_inf(aralik)
    and upper(aralik) - lower(aralik) <= interval '12 hours'
  ),
  constraint cifte_randevu_engeli exclude using gist (usta_id with =, aralik with &&)
    where (durum in ('bekliyor', 'onaylandi', 'tamamlandi'))
);
comment on table public.randevular is 'Randevular ve takvim blokları (tur = blok: mola, izin). Aynı ustada çakışan iki etkin kayıt olamaz.';
comment on column public.randevular.aralik is 'Başlangıç dahil, bitiş hariç: [başlangıç, bitiş).';
comment on column public.randevular.gec_iptal is 'Müşteri ücretsiz iptal süresi geçtikten sonra iptal ettiyse true.';

create table public.randevu_hizmetleri (
  id          uuid primary key default gen_random_uuid(),
  randevu_id  uuid not null references public.randevular (id) on delete cascade,
  hizmet_id   uuid references public.hizmetler (id) on delete set null,
  ad          text not null,
  sure_dk     integer not null check (sure_dk > 0),
  fiyat       numeric(10, 2) not null check (fiyat >= 0)
);
comment on table public.randevu_hizmetleri is 'Randevudaki hizmetler; ad, süre ve fiyat randevu anındaki haliyle saklanır.';

create table public.yorumlar (
  id            uuid primary key default gen_random_uuid(),
  randevu_id    uuid not null unique references public.randevular (id) on delete cascade,
  salon_id      uuid not null references public.salonlar (id) on delete cascade,
  usta_id       uuid,
  musteri_id    uuid references public.profiller (id) on delete set null,
  gorunen_ad    text not null,
  puan          smallint not null check (puan between 1 and 5),
  metin         text check (char_length(metin) <= 1000),
  yanit         text check (char_length(yanit) <= 1000),
  yanit_zamani  timestamptz,
  gizli         boolean not null default false,
  olusturuldu   timestamptz not null default now(),
  foreign key (usta_id, salon_id) references public.ustalar (id, salon_id) on delete set null (usta_id)
);
comment on table public.yorumlar is 'Doğrulanmış yorumlar: yalnız tamamlanan randevudan sonra, randevu başına bir kez (yorum_yaz ile).';

create table public.favori_salonlar (
  musteri_id   uuid not null references public.profiller (id) on delete cascade,
  salon_id     uuid not null references public.salonlar (id) on delete cascade,
  olusturuldu  timestamptz not null default now(),
  primary key (musteri_id, salon_id)
);

create table public.favori_ustalar (
  musteri_id   uuid not null references public.profiller (id) on delete cascade,
  usta_id      uuid not null references public.ustalar (id) on delete cascade,
  olusturuldu  timestamptz not null default now(),
  primary key (musteri_id, usta_id)
);

create table public.galeri (
  id            uuid primary key default gen_random_uuid(),
  salon_id      uuid not null references public.salonlar (id) on delete cascade,
  usta_id       uuid,
  musteri_id    uuid references public.profiller (id) on delete cascade,
  randevu_id    uuid references public.randevular (id) on delete set null,
  url           text not null,
  once_url      text,
  kategori      text not null default 'sac' check (kategori in ('sac', 'sakal', 'renk', 'bakim', 'cocuk', 'diger')),
  herkese_acik  boolean not null default false,
  aciklama      text check (char_length(aciklama) <= 300),
  olusturuldu   timestamptz not null default now(),
  foreign key (usta_id, salon_id) references public.ustalar (id, salon_id) on delete set null (usta_id)
);
comment on table public.galeri is 'Salon galerisi ve müşterinin stil geçmişi. herkese_acik = false olanları yalnız müşteri ve salon ekibi görür.';

-- İndeksler
create index salonlar_sahip on public.salonlar (sahip_id);
create index ustalar_salon on public.ustalar (salon_id);
create index ustalar_kullanici on public.ustalar (kullanici_id);
create index hizmetler_salon on public.hizmetler (salon_id);
create index usta_hizmet_hizmet on public.usta_hizmet (hizmet_id);
create index calisma_saatleri_usta on public.calisma_saatleri (usta_id, gun);
create index randevular_salon_zaman on public.randevular (salon_id, lower(aralik));
create index randevular_musteri_zaman on public.randevular (musteri_id, lower(aralik) desc);
create index randevu_hizmetleri_randevu on public.randevu_hizmetleri (randevu_id);
create index yorumlar_salon on public.yorumlar (salon_id, olusturuldu desc);
create index galeri_salon on public.galeri (salon_id, olusturuldu desc);
create index galeri_musteri on public.galeri (musteri_id);
create index favori_ustalar_usta on public.favori_ustalar (usta_id);
create index favori_salonlar_salon on public.favori_salonlar (salon_id);

-- Puan özeti (yorum yapanların izinlerine göre okunur)
create view public.salon_puanlari with (security_invoker = true) as
  select salon_id, round(avg(puan)::numeric, 1) as ortalama, count(*)::integer as adet
  from public.yorumlar
  where not gizli
  group by salon_id;

-- ----------------------------------------------------------------------------
-- 2. Tetikleyiciler
-- ----------------------------------------------------------------------------

create function public.guncelleme_zamani() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.guncellendi := now();
  return new;
end;
$$;

create trigger guncellendi before update on public.profiller for each row execute function public.guncelleme_zamani();
create trigger guncellendi before update on public.salonlar for each row execute function public.guncelleme_zamani();
create trigger guncellendi before update on public.ustalar for each row execute function public.guncelleme_zamani();
create trigger guncellendi before update on public.hizmetler for each row execute function public.guncelleme_zamani();
create trigger guncellendi before update on public.randevular for each row execute function public.guncelleme_zamani();

-- Yeni hesap açılınca profil satırı oluşur.
create function public.yeni_kullanici() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiller (id, ad_soyad, telefon)
  values (
    new.id,
    left(btrim(coalesce(new.raw_user_meta_data ->> 'ad_soyad', new.raw_user_meta_data ->> 'full_name', '')), 80),
    left(new.phone, 20)
  );
  return new;
end;
$$;

create trigger profil_olustur after insert on auth.users
  for each row execute function public.yeni_kullanici();

-- Salon sahibi doğrulama rozetini ve sahipliği değiştiremez; saat dilimi geçerli olmalı.
create function public.salon_korumasi() returns trigger
language plpgsql set search_path = '' as $$
begin
  perform now() at time zone new.saat_dilimi;
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.dogrulandi := false;
    else
      new.dogrulandi := old.dogrulandi;
      new.sahip_id := old.sahip_id;
    end if;
  end if;
  return new;
end;
$$;

create trigger salon_korumasi before insert or update on public.salonlar
  for each row execute function public.salon_korumasi();

-- ----------------------------------------------------------------------------
-- 3. Yetki yardımcıları (RLS kurallarında kullanılır)
-- ----------------------------------------------------------------------------

create function public.salon_sahibi_mi(p_salon uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.salonlar s
    where s.id = p_salon and s.sahip_id = (select auth.uid())
  );
$$;

create function public.salonda_ustayim(p_salon uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ustalar u
    where u.salon_id = p_salon and u.kullanici_id = (select auth.uid()) and u.aktif
  );
$$;

create function public.salon_ekibinde_mi(p_salon uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.salon_sahibi_mi(p_salon) or public.salonda_ustayim(p_salon);
$$;

create function public.usta_benim_mi(p_usta uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ustalar u
    where u.id = p_usta and u.kullanici_id = (select auth.uid()) and u.aktif
  );
$$;

create function public.salon_yayinda_mi(p_salon uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.salonlar s where s.id = p_salon and s.yayinda);
$$;

create function public.musterim_mi(p_musteri uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.randevular r
    where r.musteri_id = p_musteri and public.salon_ekibinde_mi(r.salon_id)
  );
$$;

create function public.randevu_ekibimin_mi(p_randevu uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.randevular r
    where r.id = p_randevu
      and (public.salon_sahibi_mi(r.salon_id) or public.usta_benim_mi(r.usta_id))
  );
$$;

-- ----------------------------------------------------------------------------
-- 4. Satır düzeyi güvenlik (RLS)
-- ----------------------------------------------------------------------------

alter table public.profiller enable row level security;
alter table public.salonlar enable row level security;
alter table public.ustalar enable row level security;
alter table public.hizmetler enable row level security;
alter table public.usta_hizmet enable row level security;
alter table public.calisma_saatleri enable row level security;
alter table public.randevular enable row level security;
alter table public.randevu_hizmetleri enable row level security;
alter table public.yorumlar enable row level security;
alter table public.favori_salonlar enable row level security;
alter table public.favori_ustalar enable row level security;
alter table public.galeri enable row level security;

-- Profiller: kişi kendini görür ve düzenler; salon ekibi kendi müşterisini görür.
create policy "profil kendisi görür" on public.profiller for select to authenticated
  using (id = (select auth.uid()));
create policy "profil salon müşterisini görür" on public.profiller for select to authenticated
  using (public.musterim_mi(id));
create policy "profil kendisi düzenler" on public.profiller for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Salonlar: yayındaki salonu herkes görür; sahibi yönetir; ustası görür.
create policy "salon yayındakini herkes görür" on public.salonlar for select to anon, authenticated
  using (yayinda);
create policy "salon sahibi ve ustası görür" on public.salonlar for select to authenticated
  using (sahip_id = (select auth.uid()) or public.salonda_ustayim(id));
create policy "salon üye açar" on public.salonlar for insert to authenticated
  with check (sahip_id = (select auth.uid()));
create policy "salon sahibi düzenler" on public.salonlar for update to authenticated
  using (sahip_id = (select auth.uid())) with check (sahip_id = (select auth.uid()));
create policy "salon sahibi siler" on public.salonlar for delete to authenticated
  using (sahip_id = (select auth.uid()));

-- Ustalar, hizmetler, usta_hizmet, çalışma saatleri: yayındaysa herkes görür; sahibi yönetir.
create policy "usta yayındakini herkes görür" on public.ustalar for select to anon, authenticated
  using (aktif and public.salon_yayinda_mi(salon_id));
create policy "usta ekip görür" on public.ustalar for select to authenticated
  using (public.salon_ekibinde_mi(salon_id));
create policy "usta sahip ekler" on public.ustalar for insert to authenticated
  with check (public.salon_sahibi_mi(salon_id));
create policy "usta sahip düzenler" on public.ustalar for update to authenticated
  using (public.salon_sahibi_mi(salon_id)) with check (public.salon_sahibi_mi(salon_id));
create policy "usta sahip siler" on public.ustalar for delete to authenticated
  using (public.salon_sahibi_mi(salon_id));

create policy "hizmet yayındakini herkes görür" on public.hizmetler for select to anon, authenticated
  using (aktif and public.salon_yayinda_mi(salon_id));
create policy "hizmet ekip görür" on public.hizmetler for select to authenticated
  using (public.salon_ekibinde_mi(salon_id));
create policy "hizmet sahip ekler" on public.hizmetler for insert to authenticated
  with check (public.salon_sahibi_mi(salon_id));
create policy "hizmet sahip düzenler" on public.hizmetler for update to authenticated
  using (public.salon_sahibi_mi(salon_id)) with check (public.salon_sahibi_mi(salon_id));
create policy "hizmet sahip siler" on public.hizmetler for delete to authenticated
  using (public.salon_sahibi_mi(salon_id));

create policy "usta_hizmet yayındakini herkes görür" on public.usta_hizmet for select to anon, authenticated
  using (public.salon_yayinda_mi(salon_id));
create policy "usta_hizmet ekip görür" on public.usta_hizmet for select to authenticated
  using (public.salon_ekibinde_mi(salon_id));
create policy "usta_hizmet sahip ekler" on public.usta_hizmet for insert to authenticated
  with check (public.salon_sahibi_mi(salon_id));
create policy "usta_hizmet sahip siler" on public.usta_hizmet for delete to authenticated
  using (public.salon_sahibi_mi(salon_id));

create policy "saat yayındakini herkes görür" on public.calisma_saatleri for select to anon, authenticated
  using (public.salon_yayinda_mi(salon_id));
create policy "saat ekip görür" on public.calisma_saatleri for select to authenticated
  using (public.salon_ekibinde_mi(salon_id));
create policy "saat sahip ekler" on public.calisma_saatleri for insert to authenticated
  with check (public.salon_sahibi_mi(salon_id));
create policy "saat sahip düzenler" on public.calisma_saatleri for update to authenticated
  using (public.salon_sahibi_mi(salon_id)) with check (public.salon_sahibi_mi(salon_id));
create policy "saat sahip siler" on public.calisma_saatleri for delete to authenticated
  using (public.salon_sahibi_mi(salon_id));

-- Randevular: müşteri kendininkini görür (alma ve iptal fonksiyonla);
-- salon sahibi tüm takvimi, usta kendi takvimini görür ve yönetir.
create policy "randevu müşteri kendininkini görür" on public.randevular for select to authenticated
  using (musteri_id = (select auth.uid()));
create policy "randevu sahip salonun takvimini görür" on public.randevular for select to authenticated
  using (public.salon_sahibi_mi(salon_id));
create policy "randevu usta kendi takvimini görür" on public.randevular for select to authenticated
  using (public.usta_benim_mi(usta_id));
create policy "randevu ekip ekler" on public.randevular for insert to authenticated
  with check (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id));
create policy "randevu ekip düzenler" on public.randevular for update to authenticated
  using (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id))
  with check (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id));
create policy "randevu ekip blok siler" on public.randevular for delete to authenticated
  using (tur = 'blok' and (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id)));

create policy "randevu hizmeti randevuyu görene görünür" on public.randevu_hizmetleri for select to authenticated
  using (exists (select 1 from public.randevular r where r.id = randevu_id));
create policy "randevu hizmeti ekip ekler" on public.randevu_hizmetleri for insert to authenticated
  with check (public.randevu_ekibimin_mi(randevu_id));
create policy "randevu hizmeti ekip düzenler" on public.randevu_hizmetleri for update to authenticated
  using (public.randevu_ekibimin_mi(randevu_id)) with check (public.randevu_ekibimin_mi(randevu_id));
create policy "randevu hizmeti ekip siler" on public.randevu_hizmetleri for delete to authenticated
  using (public.randevu_ekibimin_mi(randevu_id));

-- Yorumlar: gizlenmemiş olanı herkes okur; yazma ve yanıt fonksiyonla.
create policy "yorum herkes okur" on public.yorumlar for select to anon, authenticated
  using (not gizli);
create policy "yorum yazan görür" on public.yorumlar for select to authenticated
  using (musteri_id = (select auth.uid()));
create policy "yorum ekip görür" on public.yorumlar for select to authenticated
  using (public.salon_ekibinde_mi(salon_id));
create policy "yorum yazan siler" on public.yorumlar for delete to authenticated
  using (musteri_id = (select auth.uid()));

-- Favoriler: yalnız sahibine açık.
create policy "favori salon kendisi" on public.favori_salonlar for all to authenticated
  using (musteri_id = (select auth.uid())) with check (musteri_id = (select auth.uid()));
create policy "favori usta kendisi" on public.favori_ustalar for all to authenticated
  using (musteri_id = (select auth.uid())) with check (musteri_id = (select auth.uid()));

-- Galeri: herkese açık fotoğraf yayındaki salonda görünür; stil geçmişi müşteriye ve ekibe açık.
create policy "galeri herkese açık" on public.galeri for select to anon, authenticated
  using (herkese_acik and public.salon_yayinda_mi(salon_id));
create policy "galeri müşteri kendi stilini görür" on public.galeri for select to authenticated
  using (musteri_id = (select auth.uid()));
create policy "galeri ekip görür" on public.galeri for select to authenticated
  using (public.salon_ekibinde_mi(salon_id));
create policy "galeri ekip ekler" on public.galeri for insert to authenticated
  with check (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id));
create policy "galeri ekip düzenler" on public.galeri for update to authenticated
  using (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id))
  with check (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id));
create policy "galeri ekip siler" on public.galeri for delete to authenticated
  using (public.salon_sahibi_mi(salon_id) or public.usta_benim_mi(usta_id));

-- ----------------------------------------------------------------------------
-- 5. Randevu fonksiyonları
-- ----------------------------------------------------------------------------

-- Usta verilen anda, verilen süre için boş mu? (çalışma saati, geçmiş, çakışma, tampon)
create function public.usta_uygun_mu(p_usta uuid, p_baslangic timestamptz, p_sure_dk integer)
returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(p_sure_dk between 5 and 720, false)
    and p_baslangic >= now()
    and exists (
      select 1
      from public.ustalar u
      join public.salonlar s on s.id = u.salon_id
      join public.calisma_saatleri c on c.usta_id = u.id
      where u.id = p_usta
        and u.aktif
        and c.gun = extract(isodow from (p_baslangic at time zone s.saat_dilimi))::integer
        and (p_baslangic at time zone s.saat_dilimi)::time >= c.baslangic
        and (p_baslangic at time zone s.saat_dilimi) + make_interval(mins => p_sure_dk)
            <= (p_baslangic at time zone s.saat_dilimi)::date + c.bitis
    )
    and not exists (
      select 1
      from public.randevular r
      join public.salonlar s on s.id = r.salon_id
      where r.usta_id = p_usta
        and r.durum in ('bekliyor', 'onaylandi', 'tamamlandi')
        and r.aralik && tstzrange(
              p_baslangic - make_interval(mins => s.tampon_dk),
              p_baslangic + make_interval(mins => p_sure_dk + s.tampon_dk),
              '[)')
    );
$$;

-- Bir gün için boş saatler. p_usta boşsa "Fark etmez": tüm ustalar listelenir.
create function public.bos_saatler(
  p_salon uuid,
  p_gun date,
  p_sure_dk integer,
  p_usta uuid default null,
  p_adim_dk integer default 15
)
returns table (usta_id uuid, baslangic timestamptz)
language sql stable security definer set search_path = '' as $$
  select distinct c.usta_id, t.an
  from public.salonlar s
  join public.ustalar u
    on u.salon_id = s.id and u.aktif and (p_usta is null or u.id = p_usta)
  join public.calisma_saatleri c
    on c.usta_id = u.id and c.gun = extract(isodow from p_gun)::integer
  cross join lateral generate_series(
    (p_gun + c.baslangic) at time zone s.saat_dilimi,
    ((p_gun + c.bitis) at time zone s.saat_dilimi) - make_interval(mins => p_sure_dk),
    make_interval(mins => greatest(coalesce(p_adim_dk, 15), 5))
  ) as t (an)
  where s.id = p_salon
    and (s.yayinda or public.salon_ekibinde_mi(s.id))
    and p_sure_dk between 5 and 720
    and public.usta_uygun_mu(c.usta_id, t.an, p_sure_dk)
  order by t.an, c.usta_id;
$$;

-- Müşteri randevu alır. Fiyat ve süre sunucuda hesaplanır; usta boşsa ilk uygun usta atanır.
create function public.randevu_al(
  p_salon uuid,
  p_baslangic timestamptz,
  p_hizmetler uuid[],
  p_usta uuid default null,
  p_not text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_kullanici uuid := auth.uid();
  v_istenen integer;
  v_adet integer;
  v_sure integer;
  v_fiyat numeric(10, 2);
  v_usta uuid;
  v_id uuid;
begin
  if v_kullanici is null then
    raise exception 'Randevu almak için giriş yapmalısın.' using errcode = '42501';
  end if;

  if not exists (select 1 from public.salonlar where id = p_salon and yayinda) then
    raise exception 'Salon bulunamadı.' using errcode = 'P0002';
  end if;

  if p_baslangic > now() + interval '90 days' then
    raise exception 'En fazla 90 gün sonrasına randevu alınabilir.' using errcode = 'P0001';
  end if;

  if (select count(*) from public.randevular r
      where r.musteri_id = v_kullanici and r.salon_id = p_salon
        and r.durum in ('bekliyor', 'onaylandi') and upper(r.aralik) > now()) >= 3 then
    raise exception 'Bu salonda aynı anda en fazla 3 ileri tarihli randevun olabilir.' using errcode = 'P0001';
  end if;

  select count(distinct x) into v_istenen from unnest(p_hizmetler) as x;
  if coalesce(v_istenen, 0) = 0 then
    raise exception 'En az bir hizmet seçmelisin.' using errcode = '22023';
  end if;

  select count(*), sum(h.sure_dk), sum(h.fiyat)
    into v_adet, v_sure, v_fiyat
  from public.hizmetler h
  where h.salon_id = p_salon and h.aktif and h.id = any (p_hizmetler);

  if v_adet <> v_istenen then
    raise exception 'Seçtiğin hizmetlerden biri artık sunulmuyor.' using errcode = '22023';
  end if;

  select u.id into v_usta
  from public.ustalar u
  where u.salon_id = p_salon
    and u.aktif
    and (p_usta is null or u.id = p_usta)
    and (
      not exists (select 1 from public.usta_hizmet uh where uh.usta_id = u.id)
      or not exists (
        select 1 from unnest(p_hizmetler) as x (hizmet_id)
        where not exists (
          select 1 from public.usta_hizmet uh
          where uh.usta_id = u.id and uh.hizmet_id = x.hizmet_id
        )
      )
    )
    and public.usta_uygun_mu(u.id, p_baslangic, v_sure)
  order by u.sira, u.olusturuldu
  limit 1;

  if v_usta is null then
    raise exception 'Bu saat dolu ya da çalışma saati dışında. Başka bir saat seç.' using errcode = 'P0001';
  end if;

  insert into public.randevular (salon_id, usta_id, musteri_id, aralik, durum, kaynak, musteri_notu, toplam_fiyat)
  values (
    p_salon, v_usta, v_kullanici,
    tstzrange(p_baslangic, p_baslangic + make_interval(mins => v_sure), '[)'),
    'onaylandi', 'uygulama', nullif(btrim(p_not), ''), v_fiyat
  )
  returning id into v_id;

  insert into public.randevu_hizmetleri (randevu_id, hizmet_id, ad, sure_dk, fiyat)
  select v_id, h.id, h.ad, h.sure_dk, h.fiyat
  from public.hizmetler h
  where h.salon_id = p_salon and h.id = any (p_hizmetler)
  order by h.sira, h.ad;

  return v_id;
exception
  when exclusion_violation then
    raise exception 'Bu saat az önce doldu. Başka bir saat seç.' using errcode = 'P0001';
end;
$$;

-- Randevu iptali: müşteri kendi randevusunu, ekip salonun randevusunu iptal eder.
create function public.randevu_iptal(p_randevu uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_kullanici uuid := auth.uid();
  v_randevu public.randevular%rowtype;
  v_ucretsiz_dk integer;
  v_musteri boolean;
  v_ekip boolean;
begin
  select * into v_randevu from public.randevular where id = p_randevu for update;
  if not found then
    raise exception 'Randevu bulunamadı.' using errcode = 'P0002';
  end if;

  v_musteri := v_kullanici is not null and v_randevu.musteri_id is not distinct from v_kullanici;
  v_ekip := public.salon_sahibi_mi(v_randevu.salon_id) or public.usta_benim_mi(v_randevu.usta_id);

  if not (v_musteri or v_ekip) then
    raise exception 'Bu randevu üzerinde yetkin yok.' using errcode = '42501';
  end if;
  if v_randevu.tur <> 'randevu' or v_randevu.durum not in ('bekliyor', 'onaylandi') then
    raise exception 'Bu randevu iptal edilemez.' using errcode = '22023';
  end if;
  if not v_ekip and now() >= lower(v_randevu.aralik) then
    raise exception 'Başlamış ya da geçmiş bir randevu iptal edilemez.' using errcode = '22023';
  end if;

  select ucretsiz_iptal_dk into v_ucretsiz_dk from public.salonlar where id = v_randevu.salon_id;

  update public.randevular
     set durum = 'iptal',
         iptal_eden = v_kullanici,
         iptal_zamani = now(),
         gec_iptal = (not v_ekip) and now() > lower(v_randevu.aralik) - make_interval(mins => v_ucretsiz_dk)
   where id = p_randevu;
end;
$$;

-- Yorum: yalnız tamamlanan randevunun müşterisi, randevu başına bir kez.
create function public.yorum_yaz(p_randevu uuid, p_puan integer, p_metin text default null)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_kullanici uuid := auth.uid();
  v_randevu public.randevular%rowtype;
  v_ad text;
  v_id uuid;
begin
  select * into v_randevu from public.randevular where id = p_randevu;
  if not found or v_kullanici is null or v_randevu.musteri_id is distinct from v_kullanici then
    raise exception 'Randevu bulunamadı.' using errcode = 'P0002';
  end if;
  if v_randevu.durum <> 'tamamlandi' then
    raise exception 'Yorum yalnız tamamlanan randevudan sonra yazılabilir.' using errcode = '22023';
  end if;

  -- "Ahmet Şahin" → "Ahmet Ş."
  select btrim(ad_soyad) into v_ad from public.profiller where id = v_kullanici;
  v_ad := coalesce(v_ad, '');
  if v_ad = '' then
    v_ad := 'Maison Makas üyesi';
  elsif v_ad ~ '\s' then
    v_ad := split_part(v_ad, ' ', 1) || ' ' || left(regexp_replace(v_ad, '^.*\s', ''), 1) || '.';
  end if;

  insert into public.yorumlar (randevu_id, salon_id, usta_id, musteri_id, gorunen_ad, puan, metin)
  values (p_randevu, v_randevu.salon_id, v_randevu.usta_id, v_kullanici, v_ad, p_puan, nullif(btrim(p_metin), ''))
  returning id into v_id;

  return v_id;
exception
  when unique_violation then
    raise exception 'Bu randevu için zaten yorum yazdın.' using errcode = '23505';
end;
$$;

-- Salon sahibi yoruma yanıt verir.
create function public.yorum_yanitla(p_yorum uuid, p_yanit text)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.yorumlar y
     set yanit = nullif(btrim(p_yanit), ''),
         yanit_zamani = now()
   where y.id = p_yorum and public.salon_sahibi_mi(y.salon_id);
  if not found then
    raise exception 'Yorum bulunamadı ya da yetkin yok.' using errcode = '42501';
  end if;
end;
$$;

-- ----------------------------------------------------------------------------
-- 6. Erişim hakları
-- ----------------------------------------------------------------------------

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select on public.salonlar, public.ustalar, public.hizmetler, public.usta_hizmet,
  public.calisma_saatleri, public.yorumlar, public.galeri, public.salon_puanlari to anon;
revoke insert, update, delete, truncate on all tables in schema public from anon;
revoke truncate on all tables in schema public from authenticated;

revoke execute on function public.yeni_kullanici() from public, anon, authenticated;
revoke execute on function public.guncelleme_zamani() from public, anon, authenticated;
revoke execute on function public.salon_korumasi() from public, anon, authenticated;
revoke execute on function public.usta_uygun_mu(uuid, timestamptz, integer) from public, anon, authenticated;

revoke execute on function public.randevu_al(uuid, timestamptz, uuid[], uuid, text) from public, anon;
revoke execute on function public.randevu_iptal(uuid) from public, anon;
revoke execute on function public.yorum_yaz(uuid, integer, text) from public, anon;
revoke execute on function public.yorum_yanitla(uuid, text) from public, anon;
grant execute on function public.randevu_al(uuid, timestamptz, uuid[], uuid, text) to authenticated;
grant execute on function public.randevu_iptal(uuid) to authenticated;
grant execute on function public.yorum_yaz(uuid, integer, text) to authenticated;
grant execute on function public.yorum_yanitla(uuid, text) to authenticated;
grant execute on function public.bos_saatler(uuid, date, integer, uuid, integer) to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 7. Canlı takvim: randevu değişiklikleri uygulamalara anında gider
-- ----------------------------------------------------------------------------

alter publication supabase_realtime add table public.randevular;

commit;
