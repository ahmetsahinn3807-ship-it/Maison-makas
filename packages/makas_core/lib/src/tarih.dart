/// Türkçe tarih, saat ve para biçimleri (intl paketi olmadan).
library;

const List<String> _aylar = <String>[
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

const List<String> _aylarBuyuk = <String>[
  'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN',
  'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK',
];

const List<String> _gunler = <String>[
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];

const List<String> _gunlerBuyuk = <String>[
  'PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA', 'CUMARTESİ', 'PAZAR',
];

String maisonAy(DateTime t) => _aylar[t.month - 1];
String maisonAyBuyuk(DateTime t) => _aylarBuyuk[t.month - 1];
String maisonGun(DateTime t) => _gunler[t.weekday - 1];
String maisonGunBuyuk(DateTime t) => _gunlerBuyuk[t.weekday - 1];

/// 14:30
String maisonSaat(DateTime t) {
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 22 Ekim 2026
String maisonTarih(DateTime t) => '${t.day} ${maisonAy(t)} ${t.year}';

/// Bugün, Yarın ya da "4 gün kaldı".
String maisonKalan(DateTime hedef, {DateTime? simdi}) {
  final DateTime s = simdi ?? DateTime.now();
  final DateTime bugun = DateTime(s.year, s.month, s.day);
  final DateTime gun = DateTime(hedef.year, hedef.month, hedef.day);
  final int fark = gun.difference(bugun).inDays;
  if (fark <= 0) {
    return 'Bugün';
  }
  if (fark == 1) {
    return 'Yarın';
  }
  return '$fark gün kaldı';
}

/// Günün saatine göre selam (büyük harf).
String maisonSelamlama(DateTime simdi) {
  final int saat = simdi.hour;
  if (saat < 6) {
    return 'İYİ GECELER';
  }
  if (saat < 12) {
    return 'GÜNAYDIN';
  }
  if (saat < 18) {
    return 'İYİ GÜNLER';
  }
  return 'İYİ AKŞAMLAR';
}

/// 1.250 ₺ · 1.250,50 ₺ · 25 €
String maisonPara(num tutar, String paraBirimi) {
  final bool tam = tutar == tutar.roundToDouble();
  final String ham = tam ? tutar.round().toString() : tutar.toStringAsFixed(2);
  final List<String> parcalar = ham.split('.');
  final String tamKisim = parcalar.first;
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < tamKisim.length; i++) {
    final int kalan = tamKisim.length - i;
    b.write(tamKisim[i]);
    if (kalan > 1 && kalan % 3 == 1) {
      b.write('.');
    }
  }
  final String yazi = parcalar.length > 1 ? '${b.toString()},${parcalar[1]}' : b.toString();
  switch (paraBirimi) {
    case 'TRY':
      return '$yazi ₺';
    case 'EUR':
      return '$yazi €';
    default:
      return '$yazi $paraBirimi';
  }
}

/// 45 dk · 1 sa 30 dk
String maisonSure(int dakika) {
  if (dakika < 60) {
    return '$dakika dk';
  }
  final int sa = dakika ~/ 60;
  final int dk = dakika % 60;
  return dk == 0 ? '$sa sa' : '$sa sa $dk dk';
}
