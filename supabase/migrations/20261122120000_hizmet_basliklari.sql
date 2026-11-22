-- ============================================================================
-- Müşteri randevu sayfası: hizmetler Kadın / Erkek / Güzellik başlıkları altında listelenir.
--
-- Supabase → SQL Editor → New query → tamamını yapıştır → Run.
-- İsteğe bağlıdır: Pro uygulamasındaki hizmet formundan her hizmetin başlığı elle de seçilebilir.
-- Yanlışlıkla iki kez çalışırsa zararı yoktur. Hiçbir hizmet silinmez, ad/fiyat/süre değişmez.
--
-- Başlık, hizmetler.hedef sütunundan gelir:
--   bayan = KADIN, bay = ERKEK, ikisi = GÜZELLİK (cilt bakımı, kaş, ağda, makyaj, manikür gibi ortak işler)
--
-- Şimdiye dek eklenmiş hizmetler "ikisi" (Güzellik) olarak duruyor. Burada, Pro'nun hazır menüsündeki
-- adlarla birebir aynı olan hizmetler doğru başlığa alınır. Başka adlı hizmetlere dokunulmaz.
-- "Saç kesimi", "Saç boyama" gibi iki menüde de geçen adlar ERKEK sayılır (berber salonu varsayımı).
-- ============================================================================

begin;

update public.hizmetler
set hedef = 'bay'
where hedef = 'ikisi'
  and ad in (
    'Saç kesimi', 'Saç ve sakal', 'Saç yıkama ve fön', 'Sakal tıraşı', 'Ustura ile tıraş',
    'Sakal şekillendirme', 'Saç boyama', 'Sakal boyama', 'Çocuk saç kesimi', 'Damat tıraşı'
  );

update public.hizmetler
set hedef = 'bayan'
where hedef = 'ikisi'
  and ad in (
    'Fön ve şekillendirme', 'Perma', 'Saç boyama (kök)', 'Saç boyama (komple)',
    'Röfle ve balyaj', 'Keratin bakımı', 'Saç bakım maskesi', 'Gelin saçı ve makyajı'
  );

commit;
