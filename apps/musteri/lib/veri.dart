import 'package:flutter/widgets.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

/// Müşteri uygulamasının sunucudan okuduğu bir randevu.
@immutable
class RandevuOzet {
  const RandevuOzet({
    required this.id,
    required this.salonAd,
    required this.salonIlce,
    required this.ustaAd,
    required this.baslangic,
    required this.bitis,
    required this.durum,
    required this.toplamFiyat,
    required this.paraBirimi,
    required this.hizmetler,
  });

  factory RandevuOzet.json(Map<String, dynamic> m) {
    return RandevuOzet(
      id: m['id'] as String,
      salonAd: (m['salon_ad'] as String?) ?? '',
      salonIlce: m['salon_ilce'] as String?,
      ustaAd: (m['usta_ad'] as String?) ?? '',
      baslangic: DateTime.parse(m['baslangic'] as String).toLocal(),
      bitis: DateTime.parse(m['bitis'] as String).toLocal(),
      durum: (m['durum'] as String?) ?? '',
      toplamFiyat: (m['toplam_fiyat'] as num?)?.toDouble(),
      paraBirimi: (m['para_birimi'] as String?) ?? 'TRY',
      hizmetler: m['hizmetler'] as String?,
    );
  }

  final String id;
  final String salonAd;
  final String? salonIlce;
  final String ustaAd;
  final DateTime baslangic;
  final DateTime bitis;
  final String durum;
  final double? toplamFiyat;
  final String paraBirimi;
  final String? hizmetler;

  String get durumMetni {
    switch (durum) {
      case 'bekliyor':
        return 'Onay bekliyor';
      case 'onaylandi':
        return 'Onaylandı';
      case 'tamamlandi':
        return 'Tamamlandı';
      case 'iptal':
        return 'İptal edildi';
      case 'gelmedi':
        return 'Gelinmedi';
      default:
        return durum;
    }
  }
}

/// Keşfet listesindeki salon.
@immutable
class SalonOzet {
  const SalonOzet({
    required this.id,
    required this.ad,
    required this.ilce,
    required this.sehir,
    required this.ortalama,
    required this.yorumAdet,
    required this.dogrulandi,
    this.logoUrl,
    this.kapakUrl,
    this.kapakOdak = const Offset(0.5, 0.5),
    this.ayar = const VitrinAyari(),
  });

  factory SalonOzet.json(Map<String, dynamic> m) {
    final VitrinSalonu v = VitrinSalonu.json(m);
    return SalonOzet(
      id: v.id,
      ad: v.ad,
      ilce: v.ilce,
      sehir: v.sehir,
      ortalama: v.ortalama,
      yorumAdet: v.yorumAdet,
      dogrulandi: v.dogrulandi,
      logoUrl: v.logoUrl,
      kapakUrl: v.kapakUrl,
      kapakOdak: v.kapakOdak,
      ayar: v.ayar,
    );
  }

  final String id;
  final String ad;
  final String? ilce;
  final String? sehir;
  final double? ortalama;
  final int yorumAdet;
  final bool dogrulandi;
  final String? logoUrl;
  final String? kapakUrl;
  final Offset kapakOdak;

  /// Salonun vitrin teması ve fotoğraf filtresi.
  final VitrinAyari ayar;

  /// "4,9 · Kadıköy" ya da "Yeni · Kadıköy".
  String get ozet {
    final double? o = ortalama;
    final String puan = o == null ? 'Yeni' : o.toStringAsFixed(1).replaceAll('.', ',');
    final String yer = <String?>[ilce, sehir]
        .whereType<String>()
        .where((String s) => s.trim().isNotEmpty)
        .join(', ');
    return yer.isEmpty ? puan : '$puan · $yer';
  }

  /// Vitrin ekranının ilk anda göstereceği bilgi (ayrıntılar sunucudan gelir).
  VitrinSalonu get vitrin => VitrinSalonu(
        id: id,
        ad: ad,
        ilce: ilce,
        sehir: sehir,
        logoUrl: logoUrl,
        kapakUrl: kapakUrl,
        kapakOdak: kapakOdak,
        ayar: ayar,
        dogrulandi: dogrulandi,
        ortalama: ortalama,
        yorumAdet: yorumAdet,
      );
}

/// Sunucu çağrıları. Çevrimdışıyken (istemci yok) boş liste döner.
class Veri {
  Veri(this.oturum);

  factory Veri.of(BuildContext context) => Veri(OturumKapsami.oku(context));

  final MaisonOturum oturum;

  SupabaseClient? get _istemci => oturum.istemci;

  static List<Map<String, dynamic>> _satirlar(Object? sonuc) {
    if (sonuc is! List) {
      return <Map<String, dynamic>>[];
    }
    return sonuc.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<RandevuOzet>> randevularim({bool gecmis = false}) async {
    final SupabaseClient? i = _istemci;
    if (i == null || !oturum.girisli) {
      return <RandevuOzet>[];
    }
    final Object? sonuc =
        await i.rpc('randevularim', params: <String, dynamic>{'p_gecmis': gecmis});
    return _satirlar(sonuc).map(RandevuOzet.json).toList();
  }

  Future<List<SalonOzet>> kesfet({String? arama}) async {
    final SupabaseClient? i = _istemci;
    if (i == null) {
      return <SalonOzet>[];
    }
    final Object? sonuc = await i.rpc('kesfet', params: <String, dynamic>{'p_arama': arama});
    return _satirlar(sonuc).map(SalonOzet.json).toList();
  }

  Future<void> randevuIptal(String randevuId) async {
    final SupabaseClient? i = _istemci;
    if (i == null) {
      throw const MaisonHata('Sunucuya bağlanılamadı.');
    }
    await i.rpc('randevu_iptal', params: <String, dynamic>{'p_randevu': randevuId});
  }
}
