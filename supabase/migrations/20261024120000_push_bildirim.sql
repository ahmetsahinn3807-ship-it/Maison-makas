-- ============================================================================
-- Maison Makas · Uygulama kapalıyken bildirim (Firebase Cloud Messaging)
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- 22. adımdaki koddan sonra çalıştırılır. Yanlışlıkla iki kez çalışırsa zararı yoktur.
--
-- Telefonların bildirim adresleri (FCM jetonu) burada saklanır. Randevu alınınca ya da iptal
-- edilince uygulama "randevu-bildirimi" fonksiyonunu çağırır; fonksiyon kime ne gideceğini
-- randevu_bildirimi_hazirla ile öğrenir ve Firebase'e gönderir. Her olay için bir kez gönderilir.
-- Jetonlar yalnız bu fonksiyonlarla okunur ve yazılır; tablolara doğrudan erişim yoktur.
-- ============================================================================

begin;

create table if not exists public.bildirim_jetonlari (
  jeton         text primary key check (char_length(jeton) between 20 and 4096),
  kullanici_id  uuid not null references public.profiller (id) on delete cascade,
  uygulama      text not null check (uygulama in ('musteri', 'pro')),
  platform      text not null default 'android' check (platform in ('android', 'ios')),
  dil           text not null default 'tr' check (dil in ('tr', 'en')),
  guncellendi   timestamptz not null default now()
);
comment on table public.bildirim_jetonlari is
  'Telefonların Firebase bildirim jetonları. Bir jeton tek hesaba aittir; telefonda başka hesapla girilince el değiştirir.';
create index if not exists bildirim_jetonlari_kullanici on public.bildirim_jetonlari (kullanici_id, uygulama);

create table if not exists public.gonderilen_bildirimler (
  randevu_id  uuid not null references public.randevular (id) on delete cascade,
  olay        text not null check (olay in ('yeni', 'musteri_iptal', 'salon_iptal')),
  zaman       timestamptz not null default now(),
  primary key (randevu_id, olay)
);
comment on table public.gonderilen_bildirimler is 'Aynı olay için ikinci kez bildirim gitmesin diye tutulur.';

alter table public.bildirim_jetonlari enable row level security;
alter table public.gonderilen_bildirimler enable row level security;
revoke all on public.bildirim_jetonlari from anon, authenticated;
revoke all on public.gonderilen_bildirimler from anon, authenticated;

-- Telefon açılışta ve dil değişince jetonunu kaydeder. 90 gündür yenilenmeyen jetonlar silinir.
create or replace function public.bildirim_jetonu_kaydet(
  p_jeton text, p_uygulama text, p_platform text default 'android', p_dil text default 'tr')
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_kullanici uuid := auth.uid();
begin
  if v_kullanici is null then
    raise exception 'Önce giriş yapmalısın.' using errcode = '42501';
  end if;
  insert into public.bildirim_jetonlari (jeton, kullanici_id, uygulama, platform, dil, guncellendi)
  values (p_jeton, v_kullanici, p_uygulama, coalesce(p_platform, 'android'),
          case when p_dil = 'en' then 'en' else 'tr' end, now())
  on conflict (jeton) do update
    set kullanici_id = excluded.kullanici_id,
        uygulama = excluded.uygulama,
        platform = excluded.platform,
        dil = excluded.dil,
        guncellendi = now();
  delete from public.bildirim_jetonlari where guncellendi < now() - interval '90 days';
end;
$$;

-- Çıkış yapılınca telefon jetonunu siler (yalnız kendi jetonunu silebilir).
create or replace function public.bildirim_jetonu_sil(p_jeton text)
returns void
language sql security definer set search_path = '' as $$
  delete from public.bildirim_jetonlari where jeton = p_jeton and kullanici_id = (select auth.uid());
$$;

-- Bir randevu için gönderilecek bildirimi hazırlar ve "gönderildi" olarak işaretler.
-- Çağıran randevunun müşterisi ya da salonun ekibinden olmalıdır. Gönderilecek bir şey yoksa null.
--   yeni           müşteri uygulamadan aldı      → salon sahibi ve randevunun ustası (Makas Pro)
--   musteri_iptal  müşteri iptal etti            → salon sahibi ve randevunun ustası (Makas Pro)
--   salon_iptal    salon iptal etti              → müşteri (Maison Makas)
create or replace function public.randevu_bildirimi_hazirla(p_randevu uuid)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_kullanici uuid := auth.uid();
  r public.randevular%rowtype;
  v_salon public.salonlar%rowtype;
  v_olay text;
  v_alicilar uuid[];
  v_uygulama text;
  v_sonuc jsonb;
begin
  if v_kullanici is null then
    raise exception 'Önce giriş yapmalısın.' using errcode = '42501';
  end if;
  select * into r from public.randevular where id = p_randevu;
  if not found then
    raise exception 'Randevu bulunamadı.' using errcode = 'P0002';
  end if;
  if not (r.musteri_id is not distinct from v_kullanici
          or public.salon_sahibi_mi(r.salon_id) or public.usta_benim_mi(r.usta_id)) then
    raise exception 'Bu randevu üzerinde yetkin yok.' using errcode = '42501';
  end if;
  if r.tur <> 'randevu' or r.musteri_id is null then
    return null;
  end if;

  if r.durum = 'iptal' then
    if r.iptal_zamani is null or r.iptal_zamani < now() - interval '30 minutes' then
      return null;
    end if;
    v_olay := case when r.iptal_eden is not distinct from r.musteri_id then 'musteri_iptal' else 'salon_iptal' end;
  elsif r.kaynak = 'uygulama' and r.durum in ('bekliyor', 'onaylandi')
        and r.olusturuldu > now() - interval '30 minutes' then
    v_olay := 'yeni';
  else
    return null;
  end if;

  insert into public.gonderilen_bildirimler (randevu_id, olay) values (r.id, v_olay)
  on conflict do nothing;
  if not found then
    return null;
  end if;

  select * into v_salon from public.salonlar where id = r.salon_id;
  if v_olay = 'salon_iptal' then
    v_alicilar := array[r.musteri_id];
    v_uygulama := 'musteri';
  else
    select array_agg(distinct k) into v_alicilar
    from (
      select v_salon.sahip_id as k
      union all
      select u.kullanici_id from public.ustalar u where u.id = r.usta_id and u.aktif and u.kullanici_id is not null
    ) a;
    v_uygulama := 'pro';
  end if;

  select jsonb_build_object(
    'olay', v_olay,
    'randevu', r.id,
    'salon', v_salon.ad,
    'baslangic', to_char(lower(r.aralik) at time zone v_salon.saat_dilimi, 'YYYY-MM-DD HH24:MI'),
    'musteri', coalesce(nullif(trim(p.ad_soyad), ''), r.misafir_ad, ''),
    'usta', coalesce(u.ad, ''),
    'hizmetler', coalesce((select string_agg(h.ad, ', ' order by h.ad) from public.randevu_hizmetleri h
                           where h.randevu_id = r.id), ''),
    'alicilar', coalesce((select jsonb_agg(jsonb_build_object('jeton', j.jeton, 'dil', j.dil))
                          from public.bildirim_jetonlari j
                          where j.kullanici_id = any (v_alicilar) and j.uygulama = v_uygulama), '[]'::jsonb)
  ) into v_sonuc
  from (select 1) bir
  left join public.profiller p on p.id = r.musteri_id
  left join public.ustalar u on u.id = r.usta_id;
  return v_sonuc;
end;
$$;

revoke execute on function public.bildirim_jetonu_kaydet(text, text, text, text) from public, anon;
revoke execute on function public.bildirim_jetonu_sil(text) from public, anon;
revoke execute on function public.randevu_bildirimi_hazirla(uuid) from public, anon;
grant execute on function public.bildirim_jetonu_kaydet(text, text, text, text) to authenticated;
grant execute on function public.bildirim_jetonu_sil(text) to authenticated;
grant execute on function public.randevu_bildirimi_hazirla(uuid) to authenticated;

commit;
