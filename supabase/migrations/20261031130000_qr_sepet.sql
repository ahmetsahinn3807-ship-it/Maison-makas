-- ============================================================================
-- QR ile aile randevusu: bir telefon numarasıyla birden çok kişi için tek seferde randevu.
--
-- Sepetteki her kalem ayrı bir randevudur (kendi kişisi, hizmetleri, ustası ve saati).
-- Fonksiyon tek bir işlemdir: kalemlerden biri olmazsa hiçbiri yazılmaz.
-- ============================================================================

begin;

create or replace function public.qr_sepet_randevu_al(
  p_salon uuid,
  p_ad text,
  p_tel text,
  p_kalemler jsonb,
  p_not text default null
)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_ad text := btrim(coalesce(p_ad, ''));
  v_tel text := regexp_replace(coalesce(p_tel, ''), '[^0-9]', '', 'g');
  v_kalem jsonb;
  v_kisi text;
  v_bas timestamptz;
  v_usta uuid;
  v_hizmetler uuid[];
  v_istenen integer;
  v_adet integer;
  v_sure integer;
  v_fiyat numeric(10, 2);
  v_yaklasan integer;
  v_id uuid;
  v_sayi integer := 0;
begin
  if not exists (select 1 from public.salonlar s where s.id = p_salon and s.yayinda) then
    raise exception 'Bu salon şu anda randevu almıyor.' using errcode = '42501';
  end if;

  if char_length(v_ad) < 2 or char_length(v_ad) > 80 then
    raise exception 'İletişim için adını yaz (en az 2 harf).' using errcode = '22023';
  end if;

  if v_tel !~ '^[0-9]{10,15}$' then
    raise exception 'Telefon numarasını yaz (örnek: 0532 123 45 67).' using errcode = '22023';
  end if;

  if p_kalemler is null or jsonb_typeof(p_kalemler) <> 'array' or jsonb_array_length(p_kalemler) = 0 then
    raise exception 'Sepet boş. Önce bir randevu ekle.' using errcode = '22023';
  end if;

  if jsonb_array_length(p_kalemler) > 8 then
    raise exception 'Bir seferde en çok 8 randevu alınabilir.' using errcode = '22023';
  end if;

  select count(*) into v_yaklasan
  from public.randevular r
  where r.salon_id = p_salon
    and r.misafir_tel = v_tel
    and r.tur = 'randevu'
    and r.durum in ('bekliyor', 'onaylandi')
    and upper(r.aralik) > now();

  if v_yaklasan + jsonb_array_length(p_kalemler) > 8 then
    raise exception 'Bu telefonla salonda en çok 8 yaklaşan randevu olabilir. Değişiklik için salonu ara.' using errcode = '53400';
  end if;

  for v_kalem in select value from jsonb_array_elements(p_kalemler) as t(value) loop
    v_kisi := btrim(coalesce(v_kalem->>'kisi', ''));
    if char_length(v_kisi) < 2 or char_length(v_kisi) > 80 then
      raise exception 'Her randevu için kişinin adını yaz.' using errcode = '22023';
    end if;

    begin
      v_bas := (v_kalem->>'baslangic')::timestamptz;
    exception when others then
      raise exception 'Saat bilgisi geçersiz (%).', v_kisi using errcode = '22023';
    end;
    if v_bas < now() + interval '30 minutes' or v_bas > now() + interval '60 days' then
      raise exception 'Bu saat için randevu alınamıyor (%). Başka bir saat seç.', v_kisi using errcode = '22023';
    end if;

    begin
      v_usta := (v_kalem->>'usta')::uuid;
    exception when others then
      raise exception 'Usta bilgisi geçersiz (%).', v_kisi using errcode = '22023';
    end;
    if not exists (
      select 1 from public.ustalar u where u.id = v_usta and u.salon_id = p_salon and u.aktif
    ) then
      raise exception 'Usta bulunamadı (%).', v_kisi using errcode = 'P0002';
    end if;

    select array_agg(x::uuid) into v_hizmetler
    from jsonb_array_elements_text(coalesce(v_kalem->'hizmetler', '[]'::jsonb)) as x;
    v_istenen := coalesce(cardinality(v_hizmetler), 0);
    if v_istenen = 0 then
      raise exception 'Her kişi için en az bir hizmet seç (%).', v_kisi using errcode = '22023';
    end if;

    select count(*), sum(h.sure_dk), sum(h.fiyat)
      into v_adet, v_sure, v_fiyat
    from public.hizmetler h
    where h.salon_id = p_salon and h.aktif and h.id = any (v_hizmetler);
    if v_adet <> v_istenen then
      raise exception 'Seçilen hizmetlerden biri bu salonda yok (%).', v_kisi using errcode = '22023';
    end if;

    if not public.usta_uygun_mu(v_usta, v_bas, v_sure) then
      raise exception 'Bu saat artık boş değil (%). Sepetten çıkarıp başka bir saat seç.', v_kisi using errcode = 'P0001';
    end if;

    insert into public.randevular (
      salon_id, usta_id, tur, misafir_ad, misafir_tel, aralik, durum, kaynak, musteri_notu, toplam_fiyat
    )
    values (
      p_salon, v_usta, 'randevu', v_kisi, v_tel,
      tstzrange(v_bas, v_bas + make_interval(mins => v_sure), '[)'),
      'onaylandi', 'web', left(nullif(btrim(p_not), ''), 500), v_fiyat
    )
    returning id into v_id;

    insert into public.randevu_hizmetleri (randevu_id, hizmet_id, ad, sure_dk, fiyat)
    select v_id, h.id, h.ad, h.sure_dk, h.fiyat
    from public.hizmetler h
    where h.salon_id = p_salon and h.id = any (v_hizmetler)
    order by h.sira, h.ad;

    v_sayi := v_sayi + 1;
  end loop;

  return v_sayi;
exception
  when exclusion_violation then
    raise exception 'Sepetteki saatlerden biri az önce doldu. Sepeti kontrol edip başka saat seç.' using errcode = 'P0001';
end;
$$;

revoke execute on function public.qr_sepet_randevu_al(uuid, text, text, jsonb, text) from public;
grant execute on function public.qr_sepet_randevu_al(uuid, text, text, jsonb, text) to anon, authenticated;

commit;
