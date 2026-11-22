-- ============================================================================
-- Hizmet hedefi: her hizmet bay, bayan ya da ikisi için.
--
-- Mevcut hizmetler "ikisi" olarak kalır; hiçbir veri silinmez.
-- Randevu hizmetine hedef, randevu oluşurken hizmetten kopyalanır (tetikleyici),
-- böylece hizmet sonradan değişse bile geçmiş randevunun rengi aynı kalır.
-- Randevu fonksiyonlarına dokunulmaz.
-- ============================================================================

begin;

alter table public.hizmetler
  add column if not exists hedef text not null default 'ikisi'
  check (hedef in ('bay', 'bayan', 'ikisi'));

alter table public.randevu_hizmetleri
  add column if not exists hedef text not null default 'ikisi'
  check (hedef in ('bay', 'bayan', 'ikisi'));

create or replace function public.randevu_hizmeti_hedef()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.hedef := coalesce(
    (select h.hedef from public.hizmetler h where h.id = new.hizmet_id),
    new.hedef,
    'ikisi'
  );
  return new;
end;
$$;

drop trigger if exists randevu_hizmeti_hedef on public.randevu_hizmetleri;
create trigger randevu_hizmeti_hedef
  before insert on public.randevu_hizmetleri
  for each row execute function public.randevu_hizmeti_hedef();

-- Mevcut randevu hizmetlerine de hedefi yaz.
update public.randevu_hizmetleri rh
set hedef = h.hedef
from public.hizmetler h
where h.id = rh.hizmet_id;

commit;
