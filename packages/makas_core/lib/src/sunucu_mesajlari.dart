import 'dil.dart';

/// Veritabanı fonksiyonlarının Türkçe hata mesajlarının İngilizceleri.
///
/// Sunucu her zaman Türkçe yazar; uygulama İngilizceyse mesaj burada çevrilir. Listede olmayan
/// bir mesaj olduğu gibi gösterilir (yeni bir SQL mesajı eklenince buraya da eklenmeli).
const Map<String, String> _ingilizce = <String, String>{
  'Randevu almak için giriş yapmalısın.': 'Sign in to book an appointment.',
  'Salon bulunamadı.': 'Salon not found.',
  'En fazla 90 gün sonrasına randevu alınabilir.': 'Appointments can be booked at most 90 days ahead.',
  'Bu salonda aynı anda en fazla 3 ileri tarihli randevun olabilir.':
      'You can have at most 3 upcoming appointments at this salon.',
  'En az bir hizmet seçmelisin.': 'Choose at least one service.',
  'Seçtiğin hizmetlerden biri artık sunulmuyor.': 'One of the services you chose is no longer offered.',
  'Bu saat dolu ya da çalışma saati dışında. Başka bir saat seç.':
      'This time is taken or outside working hours. Choose another time.',
  'Bu saat az önce doldu. Başka bir saat seç.': 'This time was just taken. Choose another time.',
  'Randevu bulunamadı.': 'Appointment not found.',
  'Bu randevu üzerinde yetkin yok.': 'You are not allowed to change this appointment.',
  'Bu randevu iptal edilemez.': 'This appointment cannot be cancelled.',
  'Başlamış ya da geçmiş bir randevu iptal edilemez.': 'An appointment that has started or passed cannot be cancelled.',
  'Yorum yalnız tamamlanan randevudan sonra yazılabilir.': 'You can review only after a completed appointment.',
  'Bu randevu için zaten yorum yazdın.': 'You have already reviewed this appointment.',
  'Yorum bulunamadı ya da yetkin yok.': 'Review not found, or you are not allowed to change it.',
  'Önce giriş yapmalısın.': 'Please sign in first.',
  "Hesabına bağlı bir salon var. Hesabını Makas Pro > Ayarlar'dan silebilirsin.":
      'A salon is linked to your account. You can delete your account in Makas Pro > Settings.',
  'Bir hesap ekibe yalnız davet koduyla bağlanabilir.': 'An account can join a team only with an invite code.',
  'Bu salonu düzenleme yetkin yok.': 'You are not allowed to edit this salon.',
  'Bu ustanın saatlerini düzenleme yetkin yok.': "You are not allowed to edit this barber's hours.",
  'Çalışma saatleri okunamadı.': 'The working hours could not be read.',
  'Gün 1 (Pazartesi) ile 7 (Pazar) arasında olmalı.': 'The day must be between 1 (Monday) and 7 (Sunday).',
  'Her aralıkta bitiş saati başlangıçtan sonra olmalı.': 'In every range the end time must be after the start time.',
  'Aynı günün aralıkları çakışıyor.': 'Time ranges on the same day overlap.',
  'Bir güne en çok 4 aralık girilebilir.': 'At most 4 time ranges per day.',
  'Bu ustanın hizmetlerini düzenleme yetkin yok.': "You are not allowed to edit this barber's services.",
  'Bu usta için davet oluşturma yetkin yok.': 'You are not allowed to create an invite for this barber.',
  "Bu usta zaten Makas Pro'ya bağlı.": 'This barber is already linked to Makas Pro.',
  'Kod geçersiz ya da süresi dolmuş. Salon sahibinden yeni bir kod iste.':
      'The code is invalid or has expired. Ask the salon owner for a new code.',
  'Bu salonun ekibinde zaten varsın.': "You are already on this salon's team.",
  'Bu davet artık geçerli değil. Salon sahibinden yeni bir kod iste.':
      'This invite is no longer valid. Ask the salon owner for a new code.',
  'Bu işlem için yetkin yok.': 'You are not allowed to do this.',
  'Usta bulunamadı.': 'Barber not found.',
  'Bu ustanın takvimine yazma yetkin yok.': "You are not allowed to write to this barber's calendar.",
  'Randevu saati bugünden en çok 90 gün sonrasına kadar olabilir.':
      'The appointment can be at most 90 days from today.',
  'Seçilen hizmetlerden biri bu salonda yok.': 'One of the selected services is not offered at this salon.',
  'Süre 5 dakika ile 12 saat arasında olmalı.': 'The duration must be between 5 minutes and 12 hours.',
  'Bu ustanın o saatte başka bir kaydı var.': 'This barber already has something booked at that time.',
  'Bitiş başlangıçtan sonra olmalı.': 'The end must be after the start.',
  'Bir mola ya da izin en çok 12 saat olabilir; daha uzunsa günlere böl.':
      'A break or time off can be at most 12 hours; split longer ones into days.',
  'Bu aralıkta ustanın randevusu var. Önce randevuyu taşı ya da iptal et.':
      'The barber has an appointment in this range. Move or cancel it first.',
  'Mola ya da izin için durum değiştirilemez.': 'The status of a break or time off cannot be changed.',
  'Geçersiz durum.': 'Invalid status.',
  'İptal edilen randevunun durumu değiştirilemez.': 'The status of a cancelled appointment cannot be changed.',
  'Randevu saati gelmeden "geldi" ya da "gelmedi" işaretlenemez.':
      'You can mark "arrived" or "no-show" only once the appointment time has come.',
  'Bu saate başka bir randevu yazılmış; geri alınamaz.':
      'Another appointment has been booked at this time; this cannot be undone.',
};

final RegExp _yaklasan = RegExp(r'^Salonunda (\d+) yaklaşan randevu var\.');

/// Sunucudan gelen mesajı seçili dile çevirir.
String maisonSunucuMesaji(String mesaj) {
  if (!MaisonTercih.ingilizce) {
    return mesaj;
  }
  final String m = mesaj.trim();
  final String? karsilik = _ingilizce[m];
  if (karsilik != null) {
    return karsilik;
  }
  final RegExpMatch? y = _yaklasan.firstMatch(m);
  if (y != null) {
    final String n = y.group(1)!;
    return 'Your salon has $n upcoming appointment${n == '1' ? '' : 's'}. Cancel them first, then delete your account.';
  }
  return mesaj;
}

/// Her SQL mesajının çevirisi var mı (testler için).
bool maisonSunucuMesajiCevrili(String mesaj) => _ingilizce.containsKey(mesaj.trim());
