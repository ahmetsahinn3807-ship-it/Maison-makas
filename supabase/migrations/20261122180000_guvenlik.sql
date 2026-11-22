-- ============================================================================
-- Güvenlik sertleştirmesi.
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- İki kez çalışırsa zararı yoktur. Mevcut veriye dokunmaz.
--
--  1. QR ile (hesapsız) alınan randevulara hız sınırı: biri sahte telefonlarla art arda randevu
--     açıp salonun takvimini dolduramasın. Bir salona 10 dakikada en çok 30, saatte en çok 120
--     QR randevusu yazılabilir. (Gerçek bir salon bunun çok altında kalır.)
--  2. Ziyaretçinin (anon) görmemesi gereken kimlik alanları kapatılır:
--     salonlar.sahip_id, ustalar.kullanici_id, galeri.musteri_id, yorumlar.musteri_id.
--     Randevu sayfasının kullandığı alanlar açık kalır.
--  3. Hiçbir yerde kullanılmayan eski tek randevu fonksiyonu (qr_randevu_al) ziyaretçiye kapatılır;
--     QR sayfası qr_sepet_randevu_al kullanır.
--  4. usta_hesabini_ayir fonksiyonundaki yetki kontrolü açığı kapatılır (hesabı bağlanmamış bir
--     ustanın davet kodlarını giriş yapmış herhangi biri silebiliyordu).
-- ============================================================================

begin;

-- 1) QR randevularına hız sınırı
create or replace function public.qr_hiz_siniri()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_on_dk integer;
  v_saat integer;
begin
  if new.kaynak is distinct from 'web' then
    return new;
  end if;
  select count(*) filter (where r.olusturuldu > now() - interval '10 minutes'), count(*)
    into v_on_dk, v_saat
  from public.randevular r
  where r.salon_id = new.salon_id
    and r.kaynak = 'web'
    and r.olusturuldu > now() - interval '1 hour';
  if v_on_dk >= 30 or v_saat >= 120 then
    raise exception 'Bu salona şu anda çok fazla randevu isteği geliyor. Birkaç dakika sonra tekrar dene ya da salonu ara.'
      using errcode = '53400';
  end if;
  return new;
end;
$$;

revoke execute on function public.qr_hiz_siniri() from public, anon, authenticated;

drop trigger if exists randevular_qr_hiz_siniri on public.randevular;
create trigger randevular_qr_hiz_siniri
  before insert on public.randevular
  for each row execute function public.qr_hiz_siniri();

-- 2) Ziyaretçiden kimlik alanlarını gizle (satır kuralları değişmez; yalnız hangi sütunların okunacağı daralır)
-- NOT: Bu dört tabloya ileride yeni sütun eklenirse ve randevu sayfası onu okuyacaksa, o sütun için
--      ayrıca  grant select (sütun) on public.<tablo> to anon;  gerekir.
do $$
declare
  v_tablo text;
  v_gizli text;
  v_sutunlar text;
begin
  for v_tablo, v_gizli in
    select * from (values
      ('salonlar', 'sahip_id'),
      ('ustalar', 'kullanici_id'),
      ('galeri', 'musteri_id'),
      ('yorumlar', 'musteri_id')
    ) as t (tablo, gizli)
  loop
    select string_agg(quote_ident(c.column_name), ', ' order by c.ordinal_position)
      into v_sutunlar
    from information_schema.columns c
    where c.table_schema = 'public' and c.table_name = v_tablo and c.column_name <> v_gizli;

    execute format('revoke select on public.%I from anon', v_tablo);
    execute format('grant select (%s) on public.%I to anon', v_sutunlar, v_tablo);
  end loop;
end $$;

-- 3) Eski, kullanılmayan tek randevu fonksiyonu
do $$
begin
  if to_regprocedure('public.qr_randevu_al(uuid,timestamptz,uuid[],uuid,text,text,text)') is not null then
    revoke execute on function public.qr_randevu_al(uuid, timestamptz, uuid[], uuid, text, text, text) from public, anon, authenticated;
  end if;
end $$;

-- 4) usta_hesabini_ayir yetki kontrolü boş (NULL) değerde şaşıyordu: hesabı bağlanmamış bir ustada
--    "kullanici_id = auth.uid()" sonucu NULL çıkıp kontrol atlanıyor, yabancı biri o ustanın davet
--    kodlarını silebiliyordu. Kontrol artık kesin doğru/yanlış verir.
create or replace function public.usta_hesabini_ayir(p_usta uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_usta public.ustalar%rowtype;
begin
  select * into v_usta from public.ustalar where id = p_usta;
  if not found
     or not (public.salon_sahibi_mi(v_usta.salon_id)
             or coalesce(v_usta.kullanici_id = (select auth.uid()), false)) then
    raise exception 'Bu işlem için yetkin yok.' using errcode = '42501';
  end if;
  update public.ustalar set kullanici_id = null where id = p_usta;
  delete from public.usta_davetleri where usta_id = p_usta;
end;
$$;

commit;
