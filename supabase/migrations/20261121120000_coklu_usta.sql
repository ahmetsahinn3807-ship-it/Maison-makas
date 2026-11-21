-- ============================================================================
-- Müşteri randevu sayfası: her işleme ayrı usta (çoklu usta seçimi).
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- Yanlışlıkla iki kez çalışırsa zararı yoktur. Mevcut tabloya ve fonksiyona dokunmaz,
-- yalnız yeni fonksiyonlar ekler.
--
-- Müşteri her hizmet için ayrı usta seçebilir (saç kesimi Ali, sakal Mehmet gibi).
-- Aynı ustayı seçtiği hizmetler tek "parça" olur. Parçalar art arda yapılır:
-- birinci parça biter bitmez ikincisi başlar (aralarında boşluk yok; müşteri tek kişidir).
-- Randevular yine eskisi gibi usta başına ayrı kayıt olur (qr_sepet_randevu_al değişmedi).
--
--   musait_saatler_zincir     seçilen parçaların hepsinin art arda uygun olduğu başlangıç saatleri
--                             ve her parça için atanan usta
--   usta_hizmet_yapar_mi      (iç) usta bu hizmetlerin hepsini yapıyor mu
--   usta_sepette_dolu_mu      (iç) sepette henüz kaydedilmemiş randevularla çakışma
-- ============================================================================

begin;

-- Ustanın yaptığı hizmetler kuralı musait_saatler ile aynıdır:
-- hiç satırı olmayan usta bütün hizmetleri yapar.
create or replace function public.usta_hizmet_yapar_mi(p_usta uuid, p_hizmetler uuid[])
returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists (select 1 from public.usta_hizmet uh where uh.usta_id = p_usta)
      or not exists (
        select 1 from unnest(p_hizmetler) as x (hizmet_id)
        where not exists (
          select 1 from public.usta_hizmet uh where uh.usta_id = p_usta and uh.hizmet_id = x.hizmet_id
        )
      );
$$;

-- Müşterinin sepetinde olan ama henüz kaydedilmemiş randevular:
-- [{"usta": "...", "bas": "2026-11-30T10:00:00Z", "bit": "2026-11-30T10:30:00Z"}]
-- Tampon süresi salon ayarından gelir (usta_uygun_mu ile aynı kural).
create or replace function public.usta_sepette_dolu_mu(
  p_usta uuid,
  p_bas timestamptz,
  p_bit timestamptz,
  p_mesgul jsonb,
  p_tampon integer
)
returns boolean
language sql stable set search_path = '' as $$
  select exists (
    select 1
    from jsonb_to_recordset(coalesce(p_mesgul, '[]'::jsonb)) as m (usta uuid, bas timestamptz, bit timestamptz)
    where m.usta = p_usta
      and m.bas < p_bit + make_interval(mins => coalesce(p_tampon, 0))
      and m.bit + make_interval(mins => coalesce(p_tampon, 0)) > p_bas
  );
$$;

-- p_parcalar sıralı bir listedir; her eleman bir parçadır:
--   {"hizmetler": ["<hizmet uuid>", ...], "usta": "<usta uuid>" ya da null (fark etmez)}
-- Dönen her satır: ilk parçanın başlangıç saati ve her parça için atanan usta (parça sırasıyla).
-- İlk parça 15 dakikalık adımlarla aranır; sonraki parçalar önceki parçaların bittiği dakikada başlar.
-- "Fark etmez" parçası, başka bir parçada adıyla seçilmiş ustaya atanmaz.
create or replace function public.musait_saatler_zincir(
  p_salon uuid,
  p_bas date,
  p_gun_sayisi integer,
  p_parcalar jsonb,
  p_mesgul jsonb default '[]'::jsonb
)
returns table (baslangic timestamptz, usta_idler uuid[])
language plpgsql stable security definer set search_path = '' as $$
declare
  v_el jsonb;
  v_n integer;
  v_i integer := 0;
  v_j integer;
  v_hizl uuid[];
  v_ilk_hizl uuid[];
  v_gorulen uuid[] := '{}';
  v_sabit uuid[] := '{}';
  v_ust uuid[] := '{}';
  v_sure integer[] := '{}';
  v_ofs integer[] := '{}';
  v_yap jsonb[] := '{}';
  v_yapan jsonb;
  v_u uuid;
  v_adet integer;
  v_dk integer;
  v_toplam integer := 0;
  v_tampon integer;
  v_aday record;
  v_sec uuid[];
  v_tamam boolean;
  v_t timestamptz;
  v_son timestamptz;
begin
  if p_parcalar is null or jsonb_typeof(p_parcalar) <> 'array' then
    raise exception 'Parça listesi geçersiz.' using errcode = '22023';
  end if;
  v_n := jsonb_array_length(p_parcalar);
  if v_n < 1 or v_n > 6 then
    raise exception 'Bir randevuda en çok 6 farklı usta seçilebilir.' using errcode = '22023';
  end if;
  if p_mesgul is null then
    p_mesgul := '[]'::jsonb;
  end if;
  if jsonb_typeof(p_mesgul) <> 'array' or jsonb_array_length(p_mesgul) > 30 then
    raise exception 'Sepet bilgisi geçersiz.' using errcode = '22023';
  end if;

  select s.tampon_dk into v_tampon from public.salonlar s where s.id = p_salon;
  if not found then
    return;
  end if;

  for v_el in select value from jsonb_array_elements(p_parcalar) as t (value) loop
    v_i := v_i + 1;

    begin
      select array_agg(distinct x::uuid) into v_hizl
      from jsonb_array_elements_text(coalesce(v_el->'hizmetler', '[]'::jsonb)) as t (x);
      v_u := nullif(v_el->>'usta', '')::uuid;
    exception when others then
      raise exception 'Hizmet ya da usta bilgisi geçersiz.' using errcode = '22023';
    end;

    if coalesce(cardinality(v_hizl), 0) = 0 or cardinality(v_hizl) > 20 then
      raise exception 'Her usta için en az bir hizmet seç.' using errcode = '22023';
    end if;
    if v_gorulen && v_hizl then
      raise exception 'Aynı hizmet iki ustaya verilemez.' using errcode = '22023';
    end if;
    v_gorulen := v_gorulen || v_hizl;

    if v_u is not null then
      if v_u = any (v_sabit) then
        raise exception 'Aynı usta iki ayrı parçada olamaz.' using errcode = '22023';
      end if;
      v_sabit := array_append(v_sabit, v_u);
    end if;

    select count(*), coalesce(sum(h.sure_dk), 0)
      into v_adet, v_dk
    from public.hizmetler h
    where h.salon_id = p_salon and h.aktif and h.id = any (v_hizl);
    if v_adet <> cardinality(v_hizl) then
      raise exception 'Seçilen hizmetlerden biri artık yok. Sayfayı yenile.' using errcode = '22023';
    end if;

    select coalesce(jsonb_agg(u.id::text order by u.sira, u.id), '[]'::jsonb) into v_yapan
    from public.ustalar u
    where u.salon_id = p_salon
      and u.aktif
      and (v_u is null or u.id = v_u)
      and public.usta_hizmet_yapar_mi(u.id, v_hizl);
    if jsonb_array_length(v_yapan) = 0 then
      return;
    end if;

    if v_i = 1 then
      v_ilk_hizl := v_hizl;
    end if;
    v_ust := array_append(v_ust, v_u);
    v_sure := array_append(v_sure, v_dk);
    v_ofs := array_append(v_ofs, v_toplam);
    v_yap := array_append(v_yap, v_yapan);
    v_toplam := v_toplam + v_dk;
  end loop;

  -- İlk parçanın adayları: musait_saatler zaten çalışma saatini, mevcut randevuları ve tamponu hesaplar.
  for v_aday in
    select m.usta_id, m.baslangic
    from public.musait_saatler(p_salon, p_bas, p_gun_sayisi, v_ilk_hizl, v_ust[1]) as m
    join public.ustalar u on u.id = m.usta_id
    order by m.baslangic, u.sira, u.id
  loop
    -- Aynı başlangıç saati için tek satır dönülür.
    if v_son is not null and v_aday.baslangic = v_son then
      continue;
    end if;
    -- qr_sepet_randevu_al en az 30 dakika sonrasına randevu yazar; listede olup onayda reddedilen saat çıkmasın.
    if v_aday.baslangic < now() + interval '30 minutes' then
      continue;
    end if;
    -- "Fark etmez" parçası, adıyla seçilmiş ustayı almaz.
    if v_ust[1] is null and v_aday.usta_id = any (v_sabit) then
      continue;
    end if;
    if public.usta_sepette_dolu_mu(
         v_aday.usta_id, v_aday.baslangic,
         v_aday.baslangic + make_interval(mins => v_sure[1]), p_mesgul, v_tampon) then
      continue;
    end if;

    v_sec := array[v_aday.usta_id];
    v_tamam := true;
    for v_j in 2..v_n loop
      v_t := v_aday.baslangic + make_interval(mins => v_ofs[v_j]);
      v_u := null;
      select u.id into v_u
      from public.ustalar u
      where u.salon_id = p_salon
        and jsonb_exists(v_yap[v_j], u.id::text)
        and not (u.id = any (v_sec))
        and (v_ust[v_j] is not null or not (u.id = any (v_sabit)))
        and public.usta_uygun_mu(u.id, v_t, v_sure[v_j])
        and not public.usta_sepette_dolu_mu(
              u.id, v_t, v_t + make_interval(mins => v_sure[v_j]), p_mesgul, v_tampon)
      order by u.sira, u.id
      limit 1;
      if v_u is null then
        v_tamam := false;
        exit;
      end if;
      v_sec := array_append(v_sec, v_u);
    end loop;

    if v_tamam then
      v_son := v_aday.baslangic;
      baslangic := v_aday.baslangic;
      usta_idler := v_sec;
      return next;
    end if;
  end loop;
end;
$$;

revoke execute on function public.usta_hizmet_yapar_mi(uuid, uuid[]) from public, anon, authenticated;
revoke execute on function public.usta_sepette_dolu_mu(uuid, timestamptz, timestamptz, jsonb, integer) from public, anon, authenticated;
revoke execute on function public.musait_saatler_zincir(uuid, date, integer, jsonb, jsonb) from public;
grant execute on function public.musait_saatler_zincir(uuid, date, integer, jsonb, jsonb) to anon, authenticated;

commit;
