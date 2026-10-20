-- ============================================================================
-- Maison Makas · Uygulama fonksiyonları (17–18. adımlar)
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- 15. adımdaki temel şemadan sonra çalıştırılır. Yanlışlıkla iki kez çalışırsa zararı yoktur.
--
--   randevularim   müşterinin yaklaşan ya da geçmiş randevuları
--   kesfet         yayındaki salonlar (puanlarıyla), isteğe bağlı arama
--   salon_takvimi  Makas Pro için salonun takvimi (sahip tümünü, usta kendininkini)
--   hesabimi_sil   uygulama içinden hesap silme (App Store ve Google Play şartı);
--                  salon sahibi Makas Pro'dan salonuyla birlikte siler
-- ============================================================================

begin;

create or replace function public.randevularim(p_gecmis boolean default false)
returns table (
  id uuid,
  salon_id uuid,
  salon_ad text,
  salon_ilce text,
  usta_ad text,
  baslangic timestamptz,
  bitis timestamptz,
  durum text,
  toplam_fiyat numeric,
  para_birimi text,
  hizmetler text
)
language sql stable security definer set search_path = '' as $$
  select r.id, r.salon_id, s.ad, s.ilce, u.ad, lower(r.aralik), upper(r.aralik), r.durum,
         r.toplam_fiyat, s.para_birimi,
         (select string_agg(rh.ad, ', ' order by rh.ad)
            from public.randevu_hizmetleri rh where rh.randevu_id = r.id)
  from public.randevular r
  join public.salonlar s on s.id = r.salon_id
  join public.ustalar u on u.id = r.usta_id
  where r.musteri_id = (select auth.uid())
    and r.tur = 'randevu'
    and case
          when coalesce(p_gecmis, false)
            then upper(r.aralik) <= now() or r.durum in ('iptal', 'gelmedi', 'tamamlandi')
          else upper(r.aralik) > now() and r.durum in ('bekliyor', 'onaylandi')
        end
  order by
    case when coalesce(p_gecmis, false) then null else lower(r.aralik) end asc,
    case when coalesce(p_gecmis, false) then lower(r.aralik) end desc
  limit 100;
$$;

create or replace function public.kesfet(p_arama text default null)
returns table (
  id uuid,
  kisa_ad text,
  ad text,
  ilce text,
  sehir text,
  logo_url text,
  kapak_url text,
  dogrulandi boolean,
  ortalama numeric,
  yorum_adet integer
)
language sql stable security invoker set search_path = '' as $$
  select s.id, s.kisa_ad, s.ad, s.ilce, s.sehir, s.logo_url, s.kapak_url, s.dogrulandi,
         p.ortalama, coalesce(p.adet, 0)
  from public.salonlar s
  left join public.salon_puanlari p on p.salon_id = s.id
  where s.yayinda
    and (
      nullif(btrim(p_arama), '') is null
      or s.ad ilike '%' || btrim(p_arama) || '%'
      or s.ilce ilike '%' || btrim(p_arama) || '%'
      or s.sehir ilike '%' || btrim(p_arama) || '%'
    )
  order by s.dogrulandi desc, p.ortalama desc nulls last, s.ad
  limit 50;
$$;

create or replace function public.salon_takvimi(p_salon uuid, p_bas timestamptz, p_son timestamptz)
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
  musteri_notu text
)
language sql stable security definer set search_path = '' as $$
  select r.id, r.tur, r.usta_id, u.ad,
         coalesce(nullif(p.ad_soyad, ''), r.misafir_ad),
         coalesce(p.telefon, r.misafir_tel),
         lower(r.aralik), upper(r.aralik), r.durum, r.kaynak,
         (select string_agg(rh.ad, ', ' order by rh.ad)
            from public.randevu_hizmetleri rh where rh.randevu_id = r.id),
         r.toplam_fiyat, r.musteri_notu
  from public.randevular r
  join public.ustalar u on u.id = r.usta_id
  left join public.profiller p on p.id = r.musteri_id
  where r.salon_id = p_salon
    and r.aralik && tstzrange(p_bas, p_son, '[)')
    and (public.salon_sahibi_mi(p_salon) or public.usta_benim_mi(r.usta_id))
  order by lower(r.aralik), u.sira;
$$;

drop function if exists public.hesabimi_sil();

create or replace function public.hesabimi_sil(p_salonlarla boolean default false)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_kullanici uuid := auth.uid();
  v_yaklasan integer;
begin
  if v_kullanici is null then
    raise exception 'Önce giriş yapmalısın.' using errcode = '42501';
  end if;
  if exists (select 1 from public.salonlar where sahip_id = v_kullanici) then
    if not coalesce(p_salonlarla, false) then
      raise exception 'Hesabına bağlı bir salon var. Hesabını Makas Pro > Ayarlar''dan silebilirsin.'
        using errcode = 'P0001';
    end if;
    select count(*) into v_yaklasan
    from public.randevular r
    join public.salonlar s on s.id = r.salon_id
    where s.sahip_id = v_kullanici
      and r.tur = 'randevu'
      and r.durum in ('bekliyor', 'onaylandi')
      and upper(r.aralik) > now();
    if v_yaklasan > 0 then
      raise exception 'Salonunda % yaklaşan randevu var. Önce bunları iptal et, sonra hesabını sil.', v_yaklasan
        using errcode = 'P0001';
    end if;
    -- Salonla birlikte ekip, hizmetler, çalışma saatleri, randevular, yorumlar ve galeri silinir.
    delete from public.salonlar where sahip_id = v_kullanici;
  end if;
  -- Müşterinin henüz başlamamış randevuları iptal edilir; saat salonda boşa çıkar.
  update public.randevular
  set durum = 'iptal', iptal_zamani = now()
  where musteri_id = v_kullanici
    and tur = 'randevu'
    and durum in ('bekliyor', 'onaylandi')
    and lower(aralik) > now();
  -- Profil, favoriler ve galeri kayıtları zincirleme silinir; geçmiş randevular salonda adsız kalır.
  delete from auth.users where id = v_kullanici;
end;
$$;

revoke execute on function public.randevularim(boolean) from public, anon;
revoke execute on function public.salon_takvimi(uuid, timestamptz, timestamptz) from public, anon;
revoke execute on function public.hesabimi_sil(boolean) from public, anon;
grant execute on function public.randevularim(boolean) to authenticated;
grant execute on function public.salon_takvimi(uuid, timestamptz, timestamptz) to authenticated;
grant execute on function public.hesabimi_sil(boolean) to authenticated;
grant execute on function public.kesfet(text) to anon, authenticated;

commit;
