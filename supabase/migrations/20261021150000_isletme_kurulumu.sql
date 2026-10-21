-- ============================================================================
-- Maison Makas · İşletme kurulumu (20. adım)
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- 19. adımdaki koddan sonra çalıştırılır. Yanlışlıkla iki kez çalışırsa zararı yoktur.
--
--   hizmet_sirala              hizmet menüsünün sırası (sürükle-bırak)
--   usta_sirala                ekibin sırası
--   usta_saatlerini_kaydet     ustanın haftalık çalışma saatleri: tek seferde, denetlenerek
--   usta_hizmetlerini_kaydet   ustanın yaptığı hizmetler (boş liste = bütün hizmetler)
--   usta_davet_kodu_olustur    ustanın Makas Pro'ya kendi hesabıyla girmesi için 7 gün geçerli kod
--   usta_davetini_kabul_et     ustanın kodu girip ekibe katılması
--   usta_hesabini_ayir         ustanın hesap bağlantısını kaldırma (sahip ya da ustanın kendisi)
--   salon_saatleri             vitrin için salonun haftalık açık saatleri ve salonun yerel saati
--   salon_hazirligi            Makas Pro'daki "Salonun hazır mı?" listesi
--
-- Davet kodu veritabanında yalnız özeti (SHA-256) olarak durur; kodu salon sahibi bir kez görür.
-- Bir hesap ekibe yalnız davet koduyla bağlanır (sahip kendini "Ben de çalışıyorum" ile bağlar).
-- ============================================================================

begin;

-- 1. Davetler
create table if not exists public.usta_davetleri (
  usta_id      uuid primary key,
  salon_id     uuid not null,
  kod_ozeti    text not null unique,
  bitis        timestamptz not null,
  olusturuldu  timestamptz not null default now(),
  foreign key (usta_id, salon_id) references public.ustalar (id, salon_id) on delete cascade
);
comment on table public.usta_davetleri is
  'Ustanın Makas Pro''ya katılma kodu (yalnız SHA-256 özeti). 7 gün geçerli, tek kullanımlık.';

alter table public.usta_davetleri enable row level security;
revoke all on public.usta_davetleri from anon, authenticated;
grant select on public.usta_davetleri to authenticated;
drop policy if exists "davet sahip görür" on public.usta_davetleri;
create policy "davet sahip görür" on public.usta_davetleri for select to authenticated
  using (public.salon_sahibi_mi(salon_id));

-- 2. Bir hesap ekibe yalnız davetle bağlanır: uygulamadan yalnız boş ya da kendi hesabı yazılabilir.
create or replace function public.usta_korumasi() returns trigger
language plpgsql set search_path = '' as $$
begin
  if current_user not in ('anon', 'authenticated') or new.kullanici_id is null then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    if new.kullanici_id is not distinct from old.kullanici_id then
      return new;
    end if;
  end if;
  if new.kullanici_id is distinct from (select auth.uid()) then
    raise exception 'Bir hesap ekibe yalnız davet koduyla bağlanabilir.' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists usta_korumasi on public.ustalar;
create trigger usta_korumasi before insert or update on public.ustalar
  for each row execute function public.usta_korumasi();

-- 3. Sıralama (sürükle-bırak). Dizideki sıra yeni sıradır; salona ait olmayan kimlikler yok sayılır.
create or replace function public.hizmet_sirala(p_salon uuid, p_hizmetler uuid[])
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.salon_sahibi_mi(p_salon) then
    raise exception 'Bu salonu düzenleme yetkin yok.' using errcode = '42501';
  end if;
  update public.hizmetler h
  set sira = s.sira::integer
  from unnest(p_hizmetler) with ordinality as s (id, sira)
  where h.id = s.id and h.salon_id = p_salon and h.sira is distinct from s.sira::integer;
end;
$$;

create or replace function public.usta_sirala(p_salon uuid, p_ustalar uuid[])
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.salon_sahibi_mi(p_salon) then
    raise exception 'Bu salonu düzenleme yetkin yok.' using errcode = '42501';
  end if;
  update public.ustalar u
  set sira = s.sira::integer
  from unnest(p_ustalar) with ordinality as s (id, sira)
  where u.id = s.id and u.salon_id = p_salon and u.sira is distinct from s.sira::integer;
end;
$$;

-- 4. Haftalık çalışma saatleri: eskisi silinir, yenisi yazılır (hepsi ya da hiçbiri).
--    p_saatler: [{"gun": 1, "baslangic": "09:00", "bitis": "13:00"}, …]  gun: 1 = Pazartesi … 7 = Pazar
create or replace function public.usta_saatlerini_kaydet(p_usta uuid, p_saatler jsonb)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_salon uuid;
  v_hata text;
begin
  select u.salon_id into v_salon from public.ustalar u where u.id = p_usta;
  if v_salon is null or not public.salon_sahibi_mi(v_salon) then
    raise exception 'Bu ustanın saatlerini düzenleme yetkin yok.' using errcode = '42501';
  end if;
  if p_saatler is null or jsonb_typeof(p_saatler) <> 'array' then
    raise exception 'Çalışma saatleri okunamadı.' using errcode = '22023';
  end if;

  with yeni as (
    select (e ->> 'gun')::smallint as gun,
           (e ->> 'baslangic')::time as baslangic,
           (e ->> 'bitis')::time as bitis,
           row_number() over () as sira_no
    from jsonb_array_elements(p_saatler) as e
  )
  select case
    when exists (select 1 from yeni where gun is null or gun not between 1 and 7)
      then 'Gün 1 (Pazartesi) ile 7 (Pazar) arasında olmalı.'
    when exists (select 1 from yeni where baslangic is null or bitis is null or bitis <= baslangic)
      then 'Her aralıkta bitiş saati başlangıçtan sonra olmalı.'
    when exists (
      select 1 from yeni a join yeni b
        on a.gun = b.gun and a.sira_no < b.sira_no and a.baslangic < b.bitis and b.baslangic < a.bitis)
      then 'Aynı günün aralıkları çakışıyor.'
    when exists (select 1 from yeni group by gun having count(*) > 4)
      then 'Bir güne en çok 4 aralık girilebilir.'
  end
  into v_hata;

  if v_hata is not null then
    raise exception '%', v_hata using errcode = '22023';
  end if;

  delete from public.calisma_saatleri where usta_id = p_usta;
  insert into public.calisma_saatleri (salon_id, usta_id, gun, baslangic, bitis)
  select v_salon, p_usta, (e ->> 'gun')::smallint, (e ->> 'baslangic')::time, (e ->> 'bitis')::time
  from jsonb_array_elements(p_saatler) as e;
end;
$$;

-- 5. Ustanın yaptığı hizmetler. Boş liste: bütün hizmetler (sonradan eklenenler dahil).
create or replace function public.usta_hizmetlerini_kaydet(p_usta uuid, p_hizmetler uuid[])
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_salon uuid;
begin
  select u.salon_id into v_salon from public.ustalar u where u.id = p_usta;
  if v_salon is null or not public.salon_sahibi_mi(v_salon) then
    raise exception 'Bu ustanın hizmetlerini düzenleme yetkin yok.' using errcode = '42501';
  end if;
  delete from public.usta_hizmet where usta_id = p_usta;
  insert into public.usta_hizmet (salon_id, usta_id, hizmet_id)
  select v_salon, p_usta, h.id
  from public.hizmetler h
  where h.salon_id = v_salon and h.id = any (coalesce(p_hizmetler, '{}'::uuid[]));
end;
$$;

-- 6. Davet kodu: 8 karakter (karışan 0/O, 1/I yok), "ABCD-EFGH" biçiminde döner.
create or replace function public.usta_davet_kodu_olustur(p_usta uuid)
returns text
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_usta public.ustalar%rowtype;
  v_alfabe constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bayt bytea := uuid_send(gen_random_uuid());
  v_konumlar constant integer[] := array[0, 1, 2, 3, 4, 5, 7, 9];
  v_kod text := '';
  v_i integer;
begin
  select * into v_usta from public.ustalar where id = p_usta;
  if not found or not public.salon_sahibi_mi(v_usta.salon_id) then
    raise exception 'Bu usta için davet oluşturma yetkin yok.' using errcode = '42501';
  end if;
  if v_usta.kullanici_id is not null then
    raise exception 'Bu usta zaten Makas Pro''ya bağlı.' using errcode = 'P0001';
  end if;
  for v_i in 1..8 loop
    v_kod := v_kod || substr(v_alfabe, (get_byte(v_bayt, v_konumlar[v_i]) % 32) + 1, 1);
  end loop;
  insert into public.usta_davetleri (usta_id, salon_id, kod_ozeti, bitis)
  values (p_usta, v_usta.salon_id, encode(sha256(convert_to(v_kod, 'UTF8')), 'hex'), now() + interval '7 days')
  on conflict (usta_id) do update
    set kod_ozeti = excluded.kod_ozeti, bitis = excluded.bitis, olusturuldu = now();
  return substr(v_kod, 1, 4) || '-' || substr(v_kod, 5, 4);
end;
$$;

create or replace function public.usta_davetini_kabul_et(p_kod text)
returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_kullanici uuid := auth.uid();
  v_kod text := upper(regexp_replace(coalesce(p_kod, ''), '[^A-Za-z0-9]', '', 'g'));
  v_davet public.usta_davetleri%rowtype;
begin
  if v_kullanici is null then
    raise exception 'Önce giriş yapmalısın.' using errcode = '42501';
  end if;
  select * into v_davet
  from public.usta_davetleri
  where kod_ozeti = encode(sha256(convert_to(v_kod, 'UTF8')), 'hex') and bitis > now()
  for update;
  if not found then
    raise exception 'Kod geçersiz ya da süresi dolmuş. Salon sahibinden yeni bir kod iste.' using errcode = 'P0002';
  end if;
  if exists (
    select 1 from public.ustalar where salon_id = v_davet.salon_id and kullanici_id = v_kullanici
  ) then
    raise exception 'Bu salonun ekibinde zaten varsın.' using errcode = 'P0001';
  end if;
  update public.ustalar set kullanici_id = v_kullanici
  where id = v_davet.usta_id and kullanici_id is null;
  if not found then
    raise exception 'Bu davet artık geçerli değil. Salon sahibinden yeni bir kod iste.' using errcode = 'P0001';
  end if;
  delete from public.usta_davetleri where usta_id = v_davet.usta_id;
  return v_davet.salon_id;
end;
$$;

create or replace function public.usta_hesabini_ayir(p_usta uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_usta public.ustalar%rowtype;
begin
  select * into v_usta from public.ustalar where id = p_usta;
  if not found
     or not (public.salon_sahibi_mi(v_usta.salon_id) or v_usta.kullanici_id = (select auth.uid())) then
    raise exception 'Bu işlem için yetkin yok.' using errcode = '42501';
  end if;
  update public.ustalar set kullanici_id = null where id = p_usta;
  delete from public.usta_davetleri where usta_id = p_usta;
end;
$$;

-- 7. Vitrin: aktif ustaların saatleri gün gün birleştirilir (09–13 ve 12–20 → 09–20).
--    yerel_simdi: salonun saat diliminde şu an; uygulama "Şu an açık" bilgisini buna göre hesaplar.
create or replace function public.salon_saatleri(p_salon uuid)
returns jsonb
language sql stable security invoker set search_path = '' as $$
  with araliklar as (
    select c.gun, c.baslangic, c.bitis
    from public.calisma_saatleri c
    join public.ustalar u on u.id = c.usta_id and u.aktif
    where c.salon_id = p_salon
  ),
  isaretli as (
    select gun, baslangic, bitis,
           case when baslangic <= max(bitis) over (
                  partition by gun order by baslangic, bitis
                  rows between unbounded preceding and 1 preceding)
                then 0 else 1 end as yeni
    from araliklar
  ),
  gruplu as (
    select gun, baslangic, bitis,
           sum(yeni) over (partition by gun order by baslangic, bitis rows unbounded preceding) as grup
    from isaretli
  ),
  birlesik as (
    select gun, min(baslangic) as baslangic, max(bitis) as bitis
    from gruplu
    group by gun, grup
  )
  select jsonb_build_object(
    'yerel_simdi', (
      select to_char(now() at time zone s.saat_dilimi, 'YYYY-MM-DD"T"HH24:MI:SS')
      from public.salonlar s where s.id = p_salon
    ),
    'saatler', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'gun', b.gun,
                 'baslangic', to_char(b.baslangic, 'HH24:MI'),
                 'bitis', to_char(b.bitis, 'HH24:MI'))
               order by b.gun, b.baslangic)
      from birlesik b
    ), '[]'::jsonb)
  );
$$;

-- 8. Makas Pro "Salonun hazır mı?" listesi için sayılar (yalnız salonu görebilen okur).
create or replace function public.salon_hazirligi(p_salon uuid)
returns jsonb
language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'hizmet', (select count(*) from public.hizmetler h where h.salon_id = p_salon and h.aktif),
    'usta', (select count(*) from public.ustalar u where u.salon_id = p_salon and u.aktif),
    'saatli_usta', (
      select count(distinct c.usta_id)
      from public.calisma_saatleri c
      join public.ustalar u on u.id = c.usta_id and u.aktif
      where c.salon_id = p_salon
    ),
    'kapak', coalesce((select s.kapak_url is not null from public.salonlar s where s.id = p_salon), false),
    'aciklama', coalesce((
      select nullif(btrim(s.aciklama), '') is not null from public.salonlar s where s.id = p_salon
    ), false),
    'yayinda', coalesce((select s.yayinda from public.salonlar s where s.id = p_salon), false)
  );
$$;

-- 9. Erişim hakları
revoke execute on function public.usta_korumasi() from public, anon, authenticated;
revoke execute on function public.hizmet_sirala(uuid, uuid[]) from public, anon;
revoke execute on function public.usta_sirala(uuid, uuid[]) from public, anon;
revoke execute on function public.usta_saatlerini_kaydet(uuid, jsonb) from public, anon;
revoke execute on function public.usta_hizmetlerini_kaydet(uuid, uuid[]) from public, anon;
revoke execute on function public.usta_davet_kodu_olustur(uuid) from public, anon;
revoke execute on function public.usta_davetini_kabul_et(text) from public, anon;
revoke execute on function public.usta_hesabini_ayir(uuid) from public, anon;
revoke execute on function public.salon_hazirligi(uuid) from public, anon;
grant execute on function public.hizmet_sirala(uuid, uuid[]) to authenticated;
grant execute on function public.usta_sirala(uuid, uuid[]) to authenticated;
grant execute on function public.usta_saatlerini_kaydet(uuid, jsonb) to authenticated;
grant execute on function public.usta_hizmetlerini_kaydet(uuid, uuid[]) to authenticated;
grant execute on function public.usta_davet_kodu_olustur(uuid) to authenticated;
grant execute on function public.usta_davetini_kabul_et(text) to authenticated;
grant execute on function public.usta_hesabini_ayir(uuid) to authenticated;
grant execute on function public.salon_hazirligi(uuid) to authenticated;
grant execute on function public.salon_saatleri(uuid) to anon, authenticated;

commit;
