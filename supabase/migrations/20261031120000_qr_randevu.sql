-- ============================================================================
-- QR ile randevu: müşteri hesap açmadan, salonun QR kodunu okutup randevu alır.
--
-- Yalnız yayındaki salonlar için çalışır. Müşteri adı ve telefonu zorunludur; randevu
-- "web" kaynağıyla ve "onaylandı" durumuyla yazılır. Müşteri hesabı olmadığı için iptali
-- salonla konuşarak yapılır. Aynı telefondan bir salonda en çok 3 yaklaşan randevu alınabilir.
-- ============================================================================

begin;

create or replace function public.qr_randevu_al(
  p_salon uuid,
  p_baslangic timestamptz,
  p_hizmetler uuid[],
  p_usta uuid,
  p_ad text,
  p_tel text,
  p_not text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_ad text := btrim(coalesce(p_ad, ''));
  v_tel text := regexp_replace(coalesce(p_tel, ''), '[^0-9]', '', 'g');
  v_istenen integer;
  v_adet integer;
  v_sure integer;
  v_fiyat numeric(10, 2);
  v_yaklasan integer;
  v_id uuid;
begin
  if not exists (select 1 from public.salonlar s where s.id = p_salon and s.yayinda) then
    raise exception 'Bu salon şu anda randevu almıyor.' using errcode = '42501';
  end if;

  if char_length(v_ad) < 2 or char_length(v_ad) > 80 then
    raise exception 'Adını yaz (en az 2 harf).' using errcode = '22023';
  end if;

  if v_tel !~ '^[0-9]{10,15}$' then
    raise exception 'Telefon numarasını yaz (örnek: 0532 123 45 67).' using errcode = '22023';
  end if;

  if p_baslangic is null
     or p_baslangic < now() + interval '30 minutes'
     or p_baslangic > now() + interval '60 days' then
    raise exception 'Bu saat için randevu alınamıyor. Başka bir saat seç.' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.ustalar u where u.id = p_usta and u.salon_id = p_salon and u.aktif
  ) then
    raise exception 'Usta bulunamadı.' using errcode = 'P0002';
  end if;

  select count(distinct x) into v_istenen from unnest(coalesce(p_hizmetler, '{}'::uuid[])) as x;
  if coalesce(v_istenen, 0) = 0 then
    raise exception 'En az bir hizmet seç.' using errcode = '22023';
  end if;

  select count(*), sum(h.sure_dk), sum(h.fiyat)
    into v_adet, v_sure, v_fiyat
  from public.hizmetler h
  where h.salon_id = p_salon and h.aktif and h.id = any (p_hizmetler);

  if v_adet <> v_istenen then
    raise exception 'Seçilen hizmetlerden biri bu salonda yok.' using errcode = '22023';
  end if;

  select count(*) into v_yaklasan
  from public.randevular r
  where r.salon_id = p_salon
    and r.misafir_tel = v_tel
    and r.tur = 'randevu'
    and r.durum in ('bekliyor', 'onaylandi')
    and upper(r.aralik) > now();

  if v_yaklasan >= 3 then
    raise exception 'Bu telefonla bu salonda zaten 3 yaklaşan randevun var. Değişiklik için salonu ara.' using errcode = '53400';
  end if;

  if not public.usta_uygun_mu(p_usta, p_baslangic, v_sure) then
    raise exception 'Bu saat artık boş değil. Başka bir saat seç.' using errcode = 'P0001';
  end if;

  insert into public.randevular (
    salon_id, usta_id, tur, misafir_ad, misafir_tel, aralik, durum, kaynak, musteri_notu, toplam_fiyat
  )
  values (
    p_salon, p_usta, 'randevu', v_ad, v_tel,
    tstzrange(p_baslangic, p_baslangic + make_interval(mins => v_sure), '[)'),
    'onaylandi', 'web', left(nullif(btrim(p_not), ''), 500), v_fiyat
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

revoke execute on function public.qr_randevu_al(uuid, timestamptz, uuid[], uuid, text, text, text) from public;
grant execute on function public.qr_randevu_al(uuid, timestamptz, uuid[], uuid, text, text, text) to anon, authenticated;

commit;
