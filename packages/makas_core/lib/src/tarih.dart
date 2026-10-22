/// Tarih, saat ve para biçimleri (intl paketi olmadan); seçili dile göre.
library;

import 'dil.dart';

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

const List<String> _months = <String>[
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> _days = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String maisonAy(DateTime t) => MaisonTercih.ingilizce ? _months[t.month - 1] : _aylar[t.month - 1];
String maisonAyBuyuk(DateTime t) =>
    MaisonTercih.ingilizce ? _months[t.month - 1].toUpperCase() : _aylarBuyuk[t.month - 1];
String maisonGun(DateTime t) => MaisonTercih.ingilizce ? _days[t.weekday - 1] : _gunler[t.weekday - 1];
String maisonGunBuyuk(DateTime t) =>
    MaisonTercih.ingilizce ? _days[t.weekday - 1].toUpperCase() : _gunlerBuyuk[t.weekday - 1];

/// 14:30
String maisonSaat(DateTime t) {
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// 22 Ekim 2026 · 22 October 2026
String maisonTarih(DateTime t) => '${t.day} ${maisonAy(t)} ${t.year}';

/// Bugün, Yarın ya da "4 gün kaldı".
String maisonKalan(DateTime hedef, {DateTime? simdi}) {
  final DateTime s = simdi ?? DateTime.now();
  final DateTime bugun = DateTime(s.year, s.month, s.day);
  final DateTime gun = DateTime(hedef.year, hedef.month, hedef.day);
  final int fark = gun.difference(bugun).inDays;
  if (fark <= 0) {
    return dl('Bugün', 'Today');
  }
  if (fark == 1) {
    return dl('Yarın', 'Tomorrow');
  }
  return dl('$fark gün kaldı', 'In $fark days');
}

/// Günün saatine göre selam (büyük harf).
String maisonSelamlama(DateTime simdi) {
  final int saat = simdi.hour;
  if (saat < 6) {
    return dl('İYİ GECELER', 'GOOD NIGHT');
  }
  if (saat < 12) {
    return dl('GÜNAYDIN', 'GOOD MORNING');
  }
  if (saat < 18) {
    return dl('İYİ GÜNLER', 'GOOD AFTERNOON');
  }
  return dl('İYİ AKŞAMLAR', 'GOOD EVENING');
}

/// 1.250 ₺ · 1.250,50 ₺ · 25 € (İngilizcede ₺1,250 · ₺1,250.50 · €25)
String maisonPara(num tutar, String paraBirimi) {
  final bool en = MaisonTercih.ingilizce;
  final String binlik = en ? ',' : '.';
  final String ondalik = en ? '.' : ',';
  final bool tam = tutar == tutar.roundToDouble();
  final String ham = tam ? tutar.round().toString() : tutar.toStringAsFixed(2);
  final List<String> parcalar = ham.split('.');
  final String tamKisim = parcalar.first;
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < tamKisim.length; i++) {
    final int kalan = tamKisim.length - i;
    b.write(tamKisim[i]);
    if (kalan > 1 && kalan % 3 == 1) {
      b.write(binlik);
    }
  }
  final String yazi = parcalar.length > 1 ? '${b.toString()}$ondalik${parcalar[1]}' : b.toString();
  switch (paraBirimi) {
    case 'TRY':
      return en ? '₺$yazi' : '$yazi ₺';
    case 'EUR':
      return en ? '€$yazi' : '$yazi €';
    default:
      return '$yazi $paraBirimi';
  }
}

/// 4,9 (İngilizcede 4.9)
String maisonOndalik(double deger, [int basamak = 1]) {
  final String m = deger.toStringAsFixed(basamak);
  return MaisonTercih.ingilizce ? m : m.replaceAll('.', ',');
}

/// 45 dk · 1 sa 30 dk (İngilizcede 45 min · 1 h 30 min)
String maisonSure(int dakika) {
  final String dkEki = dl('dk', 'min');
  final String saEki = dl('sa', 'h');
  if (dakika < 60) {
    return '$dakika $dkEki';
  }
  final int sa = dakika ~/ 60;
  final int dk = dakika % 60;
  return dk == 0 ? '$sa $saEki' : '$sa $saEki $dk $dkEki';
}
