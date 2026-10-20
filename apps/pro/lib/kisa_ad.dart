/// Salon adından web adresine uygun kısa ad üretir: "Maison Şahin & Oğulları" → "maison-sahin-ogullari".
String kisaAdUret(String ad) {
  const Map<String, String> harfler = <String, String>{
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
    'é': 'e',
    'è': 'e',
    'ä': 'a',
    'ß': 'ss',
  };
  final String kucuk = ad.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final StringBuffer b = StringBuffer();
  final RegExp harfRakam = RegExp(r'[a-z0-9]');
  for (final int kod in kucuk.runes) {
    final String c = String.fromCharCode(kod);
    final String? karsilik = harfler[c];
    if (karsilik != null) {
      b.write(karsilik);
    } else if (harfRakam.hasMatch(c)) {
      b.write(c);
    } else {
      b.write('-');
    }
  }
  String sonuc = b
      .toString()
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-+'), '')
      .replaceAll(RegExp(r'-+$'), '');
  if (sonuc.length > 40) {
    sonuc = sonuc.substring(0, 40).replaceAll(RegExp(r'-+$'), '');
  }
  if (sonuc.length < 3) {
    sonuc = sonuc.isEmpty ? 'salon' : 'salon-$sonuc';
  }
  return sonuc;
}

/// Kısa ad doluysa sonuna üç haneli sayı ekler (en fazla 40 karakter).
String kisaAdEki(String kisaAd, int sayi) {
  final String govde = kisaAd.length > 36
      ? kisaAd.substring(0, 36).replaceAll(RegExp(r'-+$'), '')
      : kisaAd;
  return '$govde-$sayi';
}
