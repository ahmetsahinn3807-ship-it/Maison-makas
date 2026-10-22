import 'package:flutter/foundation.dart';

/// Makas Pro'da yönetilen salon.
@immutable
class ProSalon {
  const ProSalon({
    required this.id,
    required this.ad,
    required this.kisaAd,
    required this.ilce,
    required this.sehir,
    required this.yayinda,
    required this.sahibim,
  });

  factory ProSalon.json(Map<String, dynamic> m, {required bool sahibim}) {
    return ProSalon(
      id: m['id'] as String,
      ad: (m['ad'] as String?) ?? '',
      kisaAd: (m['kisa_ad'] as String?) ?? '',
      ilce: m['ilce'] as String?,
      sehir: m['sehir'] as String?,
      yayinda: m['yayinda'] == true,
      sahibim: sahibim,
    );
  }

  final String id;
  final String ad;
  final String kisaAd;
  final String? ilce;
  final String? sehir;
  final bool yayinda;

  /// Giriş yapan kişi salonun sahibi mi (yoksa ustası mı)?
  final bool sahibim;
}

/// Salon takvimindeki bir kayıt (randevu ya da blok).
@immutable
class TakvimKaydi {
  const TakvimKaydi({
    required this.id,
    required this.tur,
    required this.ustaId,
    required this.ustaAd,
    required this.musteriAd,
    required this.musteriTel,
    required this.baslangic,
    required this.bitis,
    required this.durum,
    required this.hizmetler,
    required this.toplamFiyat,
    required this.not,
    this.kaynak = 'uygulama',
    this.ustaNotu,
  });

  factory TakvimKaydi.json(Map<String, dynamic> m) {
    return TakvimKaydi(
      id: m['id'] as String,
      tur: (m['tur'] as String?) ?? 'randevu',
      ustaId: (m['usta_id'] as String?) ?? '',
      ustaAd: (m['usta_ad'] as String?) ?? '',
      musteriAd: m['musteri_ad'] as String?,
      musteriTel: m['musteri_tel'] as String?,
      baslangic: DateTime.parse(m['baslangic'] as String).toLocal(),
      bitis: DateTime.parse(m['bitis'] as String).toLocal(),
      durum: (m['durum'] as String?) ?? '',
      hizmetler: m['hizmetler'] as String?,
      toplamFiyat: (m['toplam_fiyat'] as num?)?.toDouble(),
      not: m['musteri_notu'] as String?,
      kaynak: (m['kaynak'] as String?) ?? 'uygulama',
      ustaNotu: m['usta_notu'] as String?,
    );
  }

  final String id;
  final String tur;
  final String ustaId;
  final String ustaAd;
  final String? musteriAd;
  final String? musteriTel;
  final DateTime baslangic;
  final DateTime bitis;
  final String durum;
  final String? hizmetler;
  final double? toplamFiyat;
  final String? not;

  /// uygulama, web ya da dukkan (kapıdan gelen / telefon)
  final String kaynak;

  /// Mola ya da izin notu (ör. "Öğle arası").
  final String? ustaNotu;

  bool get blok => tur == 'blok';

  /// Randevu saati başladı mı (geldi / gelmedi işaretlenebilir)?
  bool get basladi => !DateTime.now().isBefore(baslangic);

  String get durumMetni {
    switch (durum) {
      case 'bekliyor':
        return dl('Onay bekliyor', 'Awaiting confirmation');
      case 'onaylandi':
        return dl('Onaylandı', 'Confirmed');
      case 'tamamlandi':
        return dl('Geldi', 'Arrived');
      case 'iptal':
        return dl('İptal', 'Cancelled');
      case 'gelmedi':
        return dl('Gelmedi', 'No-show');
      default:
        return durum;
    }
  }

  bool get etkin => durum == 'bekliyor' || durum == 'onaylandi' || durum == 'tamamlandi';
}
