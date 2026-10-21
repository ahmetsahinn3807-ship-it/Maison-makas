-- ============================================================================
-- Maison Makas · Randevu akışı ve takvim (21. adım)
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- 20. adımdaki koddan sonra çalıştırılır. Yanlışlıkla iki kez çalışırsa zararı yoktur.
--
--   musait_saatler      müşterinin seçtiği hizmetlere göre boş saatler (birkaç gün birden);
--                       yalnız o hizmetleri yapan, o saatte boş ustalar
--   dukkan_randevusu    Makas Pro: kapıdan gelen ya da telefonla arayan müşteriye randevu
--   blok_ekle           Makas Pro: mola, izin ya da kapalı saat
--   randevu_durumu      Makas Pro: geldi (tamamlandı), gelmedi, onayla, geri al
--   salon_takvimi       mola ve izin notlarıyla birlikte
-- ============================================================================

begin;

-- 1. Boş saatler: [p_bas, p_bas + p_gun_sayisi) günleri, salonun saat diliminde.
--    Süre seçilen hizmetlerin toplamıdır; usta yalnız bu hizmetlerin hepsini yapıyorsa listelenir
--    (yaptığı hizmet seçilmemiş usta bütün hizmetleri yapar). 15 dakikalık adımlar.
create or replace function public.musait_saatler(
  p_salon uuid,
  p_bas date,
  p_gun_sayisi integer,
  p_hizmetler uuid[],
  p_usta uuid default null
)
returns table (usta_id uuid, baslangic timestamptz)
language sql stable security definer set search_path = '' as $$
  with istenen as (
    select count(distinct x)::integer as adet from unnest(coalesce(p_hizmetler, '{}'::uuid[])) as x
  ),
  sure as (
    select count(*)::integer as adet, coalesce(sum(h.sure_dk), 0)::integer as dk
    from public.hizmetler h
    where h.salon_id = p_salon and h.aktif and h.id = any (coalesce(p_hizmetler, '{}'::uuid[]))
  ),
  gunler as (
    select (p_bas + i)::date as gun
    from generate_series(0, least(greatest(coalesce(p_gun_sayisi, 1), 1), 31) - 1) as i
  ),
  ustalar as (
    select u.id
    from public.ustalar u
    where u.salon_id = p_salon
      and u.aktif
      and (p_usta is null or u.id = p_usta)
      and (
        not exists (select 1 from public.usta_hizmet uh where uh.usta_id = u.id)
        or not exists (
          select 1 from unnest(p_hizmetler) as x (hizmet_id)
          where not exists (
            select 1 from public.usta_hizmet uh where uh.usta_id = u.id and uh.hizmet_id = x.hizmet_id
          )
        )
      )
  )
  select distinct c.usta_id, t.an
  from public.salonlar s
  cross join istenen
  cross join sure
  cross join gunler g
  join ustalar u on true
  join public.calisma_saatleri c
    on c.usta_id = u.id and c.gun = extract(isodow from g.gun)::integer
  cross join lateral generate_series(
    (g.gun + c.baslangic) at time zone s.saat_dilimi,
    ((g.gun + c.bitis) at time zone s.saat_dilimi) - make_interval(mins => sure.dk),
    interval '15 minutes'
  ) as t (an)
  where s.id = p_salon
    and (s.yayinda or public.salon_ekibinde_mi(s.id))
    and istenen.adet > 0
    and sure.adet = istenen.adet
    and t.an >= now()
    and t.an <= now() + interval '90 days'
    and public.usta_uygun_mu(c.usta_id, t.an, sure.dk)
  order by t.an, c.usta_id;
$$;

-- 2. Kapıdan gelen ya da telefonla arayan müşteri (salon sahibi her ustaya, usta kendine yazar).
--    Hizmet seçilmezse p_sure_dk kullanılır. Çalışma saati dışına da yazılabilir; çakışma yazılamaz.
create or replace function public.dukkan_randevusu(
  p_salon uuid,
  p_usta uuid,
  p_baslangic timestamptz,
  p_hizmetler uuid[] default '{}',
  p_ad text default null,
  p_tel text default null,
  p_not text default null,
  p_sure_dk integer default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_istenen integer;
  v_adet integer;
  v_sure integer;
  v_fiyat numeric(10, 2);
  v_id uuid;
begin
  if not exists (
    select 1 from public.ustalar u where u.id = p_usta and u.salon_id = p_salon and u.aktif
  ) then
    raise exception 'Usta bulunamadı.' using errcode = 'P0002';
  end if;
  if not (public.salon_sahibi_mi(p_salon) or public.usta_benim_mi(p_usta)) then
    raise exception 'Bu ustanın takvimine yazma yetkin yok.' using errcode = '42501';
  end if;
  if p_baslangic is null or p_baslangic < now() - interval '1 day' or p_baslangic > now() + interval '90 days' then
    raise exception 'Randevu saati bugünden en çok 90 gün sonrasına kadar olabilir.' using errcode = '22023';
  end if;

  select count(distinct x) into v_istenen from unnest(coalesce(p_hizmetler, '{}'::uuid[])) as x;
  if coalesce(v_istenen, 0) > 0 then
    select count(*), sum(h.sure_dk), sum(h.fiyat)
      into v_adet, v_sure, v_fiyat
    from public.hizmetler h
    where h.salon_id = p_salon and h.id = any (p_hizmetler);
    if v_adet <> v_istenen then
      raise exception 'Seçilen hizmetlerden biri bu salonda yok.' using errcode = '22023';
    end if;
  else
    v_sure := p_sure_dk;
    v_fiyat := null;
  end if;
  if v_sure is null or v_sure not between 5 and 720 then
    raise exception 'Süre 5 dakika ile 12 saat arasında olmalı.' using errcode = '22023';
  end if;

  insert into public.randevular (
    salon_id, usta_id, tur, misafir_ad, misafir_tel, aralik, durum, kaynak, musteri_notu, toplam_fiyat
  )
  values (
    p_salon, p_usta, 'randevu',
    coalesce(nullif(btrim(p_ad), ''), 'Misafir'), nullif(btrim(p_tel), ''),
    tstzrange(p_baslangic, p_baslangic + make_interval(mins => v_sure), '[)'),
    'onaylandi', 'dukkan', nullif(btrim(p_not), ''), v_fiyat
  )
  returning id into v_id;

  if coalesce(v_istenen, 0) > 0 then
    insert into public.randevu_hizmetleri (randevu_id, hizmet_id, ad, sure_dk, fiyat)
    select v_id, h.id, h.ad, h.sure_dk, h.fiyat
    from public.hizmetler h
    where h.salon_id = p_salon and h.id = any (p_hizmetler)
    order by h.sira, h.ad;
  end if;

  return v_id;
exception
  when exclusion_violation then
    raise exception 'Bu ustanın o saatte başka bir kaydı var.' using errcode = 'P0001';
end;
$$;

-- 3. Mola, izin ya da kapalı saat: o aralıkta müşteri randevu alamaz.
create or replace function public.blok_ekle(
  p_usta uuid,
  p_baslangic timestamptz,
  p_bitis timestamptz,
  p_not text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_salon uuid;
  v_id uuid;
begin
  select u.salon_id into v_salon from public.ustalar u where u.id = p_usta;
  if v_salon is null or not (public.salon_sahibi_mi(v_salon) or public.usta_benim_mi(p_usta)) then
    raise exception 'Bu ustanın takvimine yazma yetkin yok.' using errcode = '42501';
  end if;
  if p_baslangic is null or p_bitis is null or p_bitis <= p_baslangic then
    raise exception 'Bitiş başlangıçtan sonra olmalı.' using errcode = '22023';
  end if;
  if p_bitis - p_baslangic > interval '12 hours' then
    raise exception 'Bir mola ya da izin en çok 12 saat olabilir; daha uzunsa günlere böl.' using errcode = '22023';
  end if;

  insert into public.randevular (salon_id, usta_id, tur, aralik, durum, kaynak, usta_notu)
  values (
    v_salon, p_usta, 'blok', tstzrange(p_baslangic, p_bitis, '[)'), 'onaylandi', 'dukkan',
    nullif(btrim(p_not), '')
  )
  returning id into v_id;
  return v_id;
exception
  when exclusion_violation then
    raise exception 'Bu aralıkta ustanın randevusu var. Önce randevuyu taşı ya da iptal et.' using errcode = 'P0001';
end;
$$;

-- 4. Randevu durumu (ekip): tamamlandi ve gelmedi yalnız randevu başladıktan sonra;
--    onaylandi: bekleyeni onaylar ya da yanlış işareti geri alır.
create or replace function public.randevu_durumu(p_randevu uuid, p_durum text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_randevu public.randevular%rowtype;
begin
  select * into v_randevu from public.randevular where id = p_randevu for update;
  if not found then
    raise exception 'Randevu bulunamadı.' using errcode = 'P0002';
  end if;
  if not (public.salon_sahibi_mi(v_randevu.salon_id) or public.usta_benim_mi(v_randevu.usta_id)) then
    raise exception 'Bu randevu üzerinde yetkin yok.' using errcode = '42501';
  end if;
  if v_randevu.tur <> 'randevu' then
    raise exception 'Mola ya da izin için durum değiştirilemez.' using errcode = '22023';
  end if;
  if p_durum not in ('onaylandi', 'tamamlandi', 'gelmedi') then
    raise exception 'Geçersiz durum.' using errcode = '22023';
  end if;
  if v_randevu.durum = 'iptal' then
    raise exception 'İptal edilen randevunun durumu değiştirilemez.' using errcode = '22023';
  end if;
  if p_durum in ('tamamlandi', 'gelmedi') and now() < lower(v_randevu.aralik) then
    raise exception 'Randevu saati gelmeden "geldi" ya da "gelmedi" işaretlenemez.' using errcode = '22023';
  end if;

  update public.randevular set durum = p_durum where id = p_randevu;
exception
  when exclusion_violation then
    raise exception 'Bu saate başka bir randevu yazılmış; geri alınamaz.' using errcode = 'P0001';
end;
$$;

-- 5. Takvim: mola notu (usta_notu) da gelir. Dönüş tipi değiştiği için önce kaldırılır.
drop function if exists public.salon_takvimi(uuid, timestamptz, timestamptz);
create function public.salon_takvimi(p_salon uuid, p_bas timestamptz, p_son timestamptz)
returns table (
  id uuid,
  tur text,
  usta_id uuid,
  usta_ad text,
  musteri_ad text,
  musteri_tel text,
  baslangic timestamptz,
  bitis timestamptz,
  durum text,
  kaynak text,
  hizmetler text,
  toplam_fiyat numeric,
  musteri_notu text,
  usta_notu text
)
language sql stable security definer set search_path = '' as $$
  select r.id, r.tur, r.usta_id, u.ad,
         coalesce(nullif(p.ad_soyad, ''), r.misafir_ad),
         coalesce(p.telefon, r.misafir_tel),
         lower(r.aralik), upper(r.aralik), r.durum, r.kaynak,
         (select string_agg(rh.ad, ', ' order by rh.ad)
            from public.randevu_hizmetleri rh where rh.randevu_id = r.id),
         r.toplam_fiyat, r.musteri_notu, r.usta_notu
  from public.randevular r
  join public.ustalar u on u.id = r.usta_id
  left join public.profiller p on p.id = r.musteri_id
  where r.salon_id = p_salon
    and r.aralik && tstzrange(p_bas, p_son, '[)')
    and (public.salon_sahibi_mi(p_salon) or public.usta_benim_mi(r.usta_id))
  order by lower(r.aralik), u.sira;
$$;

-- 6. Erişim hakları
revoke execute on function public.salon_takvimi(uuid, timestamptz, timestamptz) from public, anon;
grant execute on function public.salon_takvimi(uuid, timestamptz, timestamptz) to authenticated;
revoke execute on function public.musait_saatler(uuid, date, integer, uuid[], uuid) from public;
revoke execute on function public.dukkan_randevusu(uuid, uuid, timestamptz, uuid[], text, text, text, integer) from public, anon;
revoke execute on function public.blok_ekle(uuid, timestamptz, timestamptz, text) from public, anon;
revoke execute on function public.randevu_durumu(uuid, text) from public, anon;
grant execute on function public.musait_saatler(uuid, date, integer, uuid[], uuid) to anon, authenticated;
grant execute on function public.dukkan_randevusu(uuid, uuid, timestamptz, uuid[], text, text, text, integer) to authenticated;
grant execute on function public.blok_ekle(uuid, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.randevu_durumu(uuid, text) to authenticated;

commit;
