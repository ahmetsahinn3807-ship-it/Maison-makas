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
        return dl('Onay bekliyor', 'Awaiting confirmation');
      case 'onaylandi':
        return dl('Onaylandı', 'Confirmed');
      case 'tamamlandi':
        return dl('Tamamlandı', 'Completed');
      case 'iptal':
        return dl('İptal edildi', 'Cancelled');
      case 'gelmedi':
        return dl('Gelinmedi', 'No-show');
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
    final String puan = o == null ? dl('Yeni', 'New') : maisonOndalik(o);
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

/// Boş bir randevu saati: hangi usta, ne zaman (telefonun saatine çevrilmiş).
@immutable
class BosSaat {
  const BosSaat({required this.ustaId, required this.baslangic});

  final String ustaId;
  final DateTime baslangic;
}

/// Sunucu çağrıları. Çevrimdışıyken (istemci yok) boş liste döner.
class Veri {
  Veri(this.oturum);

  /// Randevu alınınca ya da iptal edilince artar; randevu listeleri yeniden yüklenir.
  static final ValueNotifier<int> randevuSurumu = ValueNotifier<int>(0);

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

  /// [bas] gününden başlayarak [gunSayisi] gün boyunca seçilen hizmetler için boş saatler.
  Future<List<BosSaat>> bosSaatler({
    required String salonId,
    required DateTime bas,
    required int gunSayisi,
    required List<String> hizmetler,
    String? ustaId,
  }) async {
    final SupabaseClient i = await oturum.istemciGerekli();
    final String gun = '${bas.year.toString().padLeft(4, '0')}-${bas.month.toString().padLeft(2, '0')}-'
        '${bas.day.toString().padLeft(2, '0')}';
    final Object? sonuc = await i.rpc('musait_saatler', params: <String, dynamic>{
      'p_salon': salonId,
      'p_bas': gun,
      'p_gun_sayisi': gunSayisi,
      'p_hizmetler': hizmetler,
      'p_usta': ustaId,
    });
    final List<BosSaat> liste = <BosSaat>[];
    for (final Map<String, dynamic> m in _satirlar(sonuc)) {
      final Object? usta = m['usta_id'];
      final Object? an = m['baslangic'];
      final DateTime? zaman = an is String ? DateTime.tryParse(an)?.toLocal() : null;
      if (usta is String && zaman != null) {
        liste.add(BosSaat(ustaId: usta, baslangic: zaman));
      }
    }
    return liste;
  }

  /// Randevu alır ve kimliğini döndürür. [ustaId] boşsa sunucu ilk uygun ustayı seçer.
  Future<String> randevuAl({
    required String salonId,
    required DateTime baslangic,
    required List<String> hizmetler,
    String? ustaId,
    String? not,
  }) async {
    final SupabaseClient i = await oturum.istemciGerekli();
    final Object? sonuc = await i.rpc('randevu_al', params: <String, dynamic>{
      'p_salon': salonId,
      'p_baslangic': baslangic.toUtc().toIso8601String(),
      'p_hizmetler': hizmetler,
      'p_usta': ustaId,
      'p_not': not,
    });
    if (sonuc is! String) {
      throw MaisonHata(dl('Randevu alınamadı. Bir daha dene.', 'The booking could not be made. Try again.'));
    }
    randevuSurumu.value++;
    return sonuc;
  }

  /// Alınan randevunun ustası (müşteri kendi randevusunu görebilir).
  Future<String?> randevununUstasi(String randevuId) async {
    final SupabaseClient? i = _istemci;
    if (i == null) {
      return null;
    }
    final Map<String, dynamic>? satir =
        await i.from('randevular').select('usta_id').eq('id', randevuId).maybeSingle();
    final Object? usta = satir?['usta_id'];
    return usta is String ? usta : null;
  }

  Future<void> randevuIptal(String randevuId) async {
    final SupabaseClient? i = _istemci;
    if (i == null) {
      throw MaisonHata(dl('Sunucuya bağlanılamadı.', 'Could not connect to the server.'));
    }
    await i.rpc('randevu_iptal', params: <String, dynamic>{'p_randevu': randevuId});
    randevuSurumu.value++;
  }
}
