import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:makas_core/makas_core.dart';

void main() {
  tearDown(() => MaisonTercih.dil.value = MaisonDil.tr);

  test('dl seçili dile göre metin verir', () {
    MaisonTercih.dil.value = MaisonDil.tr;
    expect(dl('Kaydet', 'Save'), 'Kaydet');
    MaisonTercih.dil.value = MaisonDil.en;
    expect(dl('Kaydet', 'Save'), 'Save');
    expect(MaisonDil.addan('de'), isNull);
    expect(MaisonDil.addan('en'), MaisonDil.en);
  });

  test('Tarih, para ve süre biçimleri dile uyar', () {
    final DateTime t = DateTime(2026, 10, 22, 14, 5);
    MaisonTercih.dil.value = MaisonDil.tr;
    expect(maisonTarih(t), '22 Ekim 2026');
    expect(maisonGun(t), 'Perşembe');
    expect(maisonPara(1250.5, 'TRY'), '1.250,50 ₺');
    expect(maisonSure(90), '1 sa 30 dk');
    expect(maisonGunKisa(1), 'Pzt');
    expect(maisonBuyukHarf('Diğer'), 'DİĞER');
    expect(HizmetKategorisi.sakal.ad, 'Sakal');

    MaisonTercih.dil.value = MaisonDil.en;
    expect(maisonTarih(t), '22 October 2026');
    expect(maisonGun(t), 'Thursday');
    expect(maisonPara(1250.5, 'TRY'), '₺1,250.50');
    expect(maisonPara(25, 'EUR'), '€25');
    expect(maisonSure(90), '1 h 30 min');
    expect(maisonSure(45), '45 min');
    expect(maisonGunKisa(1), 'Mon');
    expect(maisonBuyukHarf('Other'), 'OTHER');
    expect(maisonOndalik(4.9), '4.9');
    expect(HizmetKategorisi.sakal.ad, 'Beard');
    expect(maisonKalan(DateTime.now().add(const Duration(days: 1))), 'Tomorrow');
  });

  test('Salonun açık/kapalı satırı İngilizcede de kurulur', () {
    MaisonTercih.dil.value = MaisonDil.en;
    final DateTime an = DateTime(2026, 10, 22, 8, 0);
    final SalonSaatleri saatler = SalonSaatleri(
      araliklar: <CalismaAraligi>[
        for (int g = 1; g <= 7; g++) CalismaAraligi(gun: g, baslangic: 9 * 60, bitis: 20 * 60),
      ],
      yerelSimdi: an,
      alindi: an,
    );
    expect(saatler.durum(an)?.metin, 'Closed now · opens at 09:00');
    expect(saatler.durum(DateTime(2026, 10, 22, 10, 0))?.metin, 'Open now · closes at 20:00');
    MaisonTercih.dil.value = MaisonDil.tr;
    expect(saatler.durum(an)?.metin, "Şu an kapalı · 09:00'da açılır");
  });

  test('Sunucunun her Türkçe hata mesajının İngilizcesi var', () {
    final Directory klasor = Directory('../../supabase/migrations');
    if (!klasor.existsSync()) {
      return; // Depo dışında çalışıyorsa atlanır.
    }
    final RegExp raise = RegExp(r"raise\s+exception\s+'((?:[^']|'')*)'", caseSensitive: false);
    final RegExp sonra = RegExp(r"then\s+'((?:[^']|'')*)'");
    final List<String> eksik = <String>[];
    for (final FileSystemEntity f in klasor.listSync()) {
      if (f is! File || !f.path.endsWith('.sql')) {
        continue;
      }
      final String sql = f.readAsStringSync();
      for (final RegExpMatch m in <RegExpMatch>[...raise.allMatches(sql), ...sonra.allMatches(sql)]) {
        final String mesaj = m.group(1)!.replaceAll("''", "'");
        if (!mesaj.endsWith('.')) {
          continue;
        }
        if (mesaj.contains('%')) {
          continue; // Biçimli mesajlar (ör. "Salonunda % yaklaşan randevu var") ayrıca denetlenir.
        }
        if (!maisonSunucuMesajiCevrili(mesaj)) {
          eksik.add(mesaj);
        }
      }
    }
    expect(eksik, isEmpty);

    MaisonTercih.dil.value = MaisonDil.en;
    expect(
      maisonSunucuMesaji('Salonunda 2 yaklaşan randevu var. Önce bunları iptal et, sonra hesabını sil.'),
      'Your salon has 2 upcoming appointments. Cancel them first, then delete your account.',
    );
    expect(maisonSunucuMesaji('Randevu bulunamadı.'), 'Appointment not found.');
    MaisonTercih.dil.value = MaisonDil.tr;
    expect(maisonSunucuMesaji('Randevu bulunamadı.'), 'Randevu bulunamadı.');
  });
}
