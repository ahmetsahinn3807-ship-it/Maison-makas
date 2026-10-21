import 'package:flutter_test/flutter_test.dart';
import 'package:makas_core/makas_core.dart';

void main() {
  test('Saat ekleri Türkçe ses uyumuna uyar', () {
    expect(maisonSaatEki(20 * 60), "20:00'de");
    expect(maisonSaatEki(13 * 60), "13:00'te");
    expect(maisonSaatEki(9 * 60 + 30), "09:30'da");
    expect(maisonSaatEki(14 * 60 + 40), "14:40'ta");
    expect(maisonSaatEki(10 * 60), "10:00'da");
    expect(maisonSaatEki(12 * 60), "12:00'de");
    expect(maisonSaatEki(16 * 60), "16:00'da");
    expect(maisonSaatEki(24 * 60), "24:00'te");
    expect(maisonSaatEki(8 * 60 + 15), "08:15'te");
  });

  test('Dakika metni okunur ve yazılır', () {
    expect(maisonDakikaMetni(545), '09:05');
    expect(maisonDakikaMetni(1440), '24:00');
    expect(maisonDakikaOku('09:00:00'), 540);
    expect(maisonDakikaOku('24:00:00'), 1440);
    expect(maisonDakikaOku('25:00'), isNull);
    expect(maisonDakikaOku(null), isNull);
  });

  test('Hafta özeti aynı saatlerdeki ardışık günleri birleştirir', () {
    final List<CalismaAraligi> araliklar = <CalismaAraligi>[
      for (int gun = 1; gun <= 5; gun++) ...<CalismaAraligi>[
        CalismaAraligi(gun: gun, baslangic: 540, bitis: 780),
        CalismaAraligi(gun: gun, baslangic: 840, bitis: 1200),
      ],
      const CalismaAraligi(gun: 6, baslangic: 600, bitis: 1080),
    ];
    expect(
      maisonHaftaOzeti(araliklar),
      <String>['Pzt–Cum 09:00–13:00, 14:00–20:00', 'Cmt 10:00–18:00'],
    );
    expect(maisonHaftaOzeti(const <CalismaAraligi>[]), isEmpty);
  });

  test('Gün denetimi çakışmayı ve ters saati yakalar', () {
    expect(
      maisonGunDenetle(const <CalismaAraligi>[
        CalismaAraligi(gun: 1, baslangic: 540, bitis: 780),
        CalismaAraligi(gun: 1, baslangic: 720, bitis: 900),
      ]),
      'Pazartesi: aralıklar çakışıyor.',
    );
    expect(
      maisonGunDenetle(const <CalismaAraligi>[CalismaAraligi(gun: 2, baslangic: 900, bitis: 600)]),
      'Salı: bitiş saati başlangıçtan sonra olmalı.',
    );
    expect(
      maisonGunDenetle(const <CalismaAraligi>[
        CalismaAraligi(gun: 3, baslangic: 540, bitis: 780),
        CalismaAraligi(gun: 3, baslangic: 780, bitis: 1200),
      ]),
      isNull,
    );
  });

  test('Salonun açık ya da kapalı olduğu salonun yerel saatine göre hesaplanır', () {
    final SalonSaatleri saatler = SalonSaatleri.json(<String, dynamic>{
      'yerel_simdi': '2026-10-21T15:00:00', // Çarşamba
      'saatler': <Map<String, dynamic>>[
        <String, dynamic>{'gun': 3, 'baslangic': '09:00', 'bitis': '20:00'},
        <String, dynamic>{'gun': 4, 'baslangic': '10:00', 'bitis': '18:00'},
      ],
    });
    final DateTime alindi = saatler.alindi;
    expect(saatler.durum(alindi)?.metin, "Şu an açık · 20:00'de kapanır");
    expect(saatler.durum(alindi)?.acik, isTrue);
    expect(
      saatler.durum(alindi.add(const Duration(hours: 6)))?.metin,
      "Şu an kapalı · Yarın 10:00'da açılır",
    );
    expect(
      saatler.durum(alindi.subtract(const Duration(hours: 7)))?.metin,
      "Şu an kapalı · 09:00'da açılır",
    );
    expect(
      saatler.durum(alindi.add(const Duration(days: 1, hours: 4)))?.metin,
      "Şu an kapalı · Çarşamba 09:00'da açılır",
    );
    expect(SalonSaatleri.json(null).durum(), isNull);
  });

  test('Fiyat Türkçe yazımla okunur', () {
    expect(maisonFiyatOku('400'), 400);
    expect(maisonFiyatOku('1.250'), 1250);
    expect(maisonFiyatOku('250,50'), 250.5);
    expect(maisonFiyatOku('12.5'), 12.5);
    expect(maisonFiyatOku(' 300 ₺'), 300);
    expect(maisonFiyatOku('abc'), isNull);
    expect(maisonFiyatYaz(250.5), '250,50');
    expect(maisonFiyatYaz(400), '400');
  });

  test('Türkçe büyük harf', () {
    expect(maisonBuyukHarf('Diğer'), 'DİĞER');
    expect(maisonBuyukHarf('Bakım'), 'BAKIM');
  });
}
