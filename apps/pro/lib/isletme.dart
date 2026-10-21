import 'package:flutter/foundation.dart';
import 'package:makas_core/makas_core.dart';

/// Salonun hizmet menüsünde bir kalem (Makas Pro'da düzenlenen hâli).
@immutable
class ProHizmet {
  const ProHizmet({
    required this.id,
    required this.ad,
    required this.kategori,
    required this.sureDk,
    required this.fiyat,
    this.aciklama,
    this.aktif = true,
    this.sira = 0,
  });

  factory ProHizmet.json(Map<String, dynamic> m) {
    return ProHizmet(
      id: m['id'] as String,
      ad: (m['ad'] as String?) ?? '',
      aciklama: m['aciklama'] as String?,
      kategori: HizmetKategorisi.kimliktenBul(m['kategori']),
      sureDk: (m['sure_dk'] as num?)?.toInt() ?? 30,
      fiyat: (m['fiyat'] as num?)?.toDouble() ?? 0,
      aktif: m['aktif'] != false,
      sira: (m['sira'] as num?)?.toInt() ?? 0,
    );
  }

  /// Sorgularda istenen sütunlar.
  static const String sutunlar = 'id, ad, aciklama, kategori, sure_dk, fiyat, aktif, sira';

  final String id;
  final String ad;
  final String? aciklama;
  final HizmetKategorisi kategori;
  final int sureDk;
  final double fiyat;
  final bool aktif;
  final int sira;

  /// Kaydedilecek alanlar (salon ve sıra hariç).
  Map<String, dynamic> kayit() => <String, dynamic>{
        'ad': ad,
        'aciklama': aciklama,
        'kategori': kategori.kimlik,
        'sure_dk': sureDk,
        'fiyat': fiyat,
        'aktif': aktif,
      };

  ProHizmet copyWith({int? sira, bool? aktif}) {
    return ProHizmet(
      id: id,
      ad: ad,
      aciklama: aciklama,
      kategori: kategori,
      sureDk: sureDk,
      fiyat: fiyat,
      aktif: aktif ?? this.aktif,
      sira: sira ?? this.sira,
    );
  }
}

/// Bir hizmetin kayıttan önceki hâli (yeni ya da düzenlenmiş).
@immutable
class HizmetTaslagi {
  const HizmetTaslagi({
    required this.ad,
    required this.kategori,
    required this.sureDk,
    required this.fiyat,
    this.aciklama,
    this.aktif = true,
  });

  final String ad;
  final HizmetKategorisi kategori;
  final int sureDk;
  final double fiyat;
  final String? aciklama;
  final bool aktif;

  Map<String, dynamic> kayit() => <String, dynamic>{
        'ad': ad,
        'aciklama': aciklama,
        'kategori': kategori.kimlik,
        'sure_dk': sureDk,
        'fiyat': fiyat,
        'aktif': aktif,
      };
}

/// Ekipte bir usta (Makas Pro'da yönetilen hâli).
@immutable
class ProUsta {
  const ProUsta({
    required this.id,
    required this.ad,
    this.unvan,
    this.fotoUrl,
    this.uzmanlik = const <String>[],
    this.aktif = true,
    this.sira = 0,
    this.kullaniciId,
  });

  factory ProUsta.json(Map<String, dynamic> m) {
    final Object? uzmanlik = m['uzmanlik'];
    return ProUsta(
      id: m['id'] as String,
      ad: (m['ad'] as String?) ?? '',
      unvan: m['unvan'] as String?,
      fotoUrl: m['foto_url'] as String?,
      uzmanlik: uzmanlik is List ? uzmanlik.whereType<String>().toList() : const <String>[],
      aktif: m['aktif'] != false,
      sira: (m['sira'] as num?)?.toInt() ?? 0,
      kullaniciId: m['kullanici_id'] as String?,
    );
  }

  static const String sutunlar = 'id, ad, unvan, foto_url, uzmanlik, aktif, sira, kullanici_id';

  final String id;
  final String ad;
  final String? unvan;
  final String? fotoUrl;
  final List<String> uzmanlik;
  final bool aktif;
  final int sira;

  /// Usta Makas Pro'ya kendi hesabıyla giriyorsa hesabın kimliği.
  final String? kullaniciId;

  bool get hesapBagli => kullaniciId != null;

  String get basHarfler {
    final List<String> kelimeler =
        ad.trim().split(RegExp(r'\s+')).where((String k) => k.isNotEmpty).toList();
    if (kelimeler.isEmpty) {
      return 'U';
    }
    final String ilk = kelimeler.first.substring(0, 1);
    final String son = kelimeler.length > 1 ? kelimeler.last.substring(0, 1) : '';
    return maisonBuyukHarf(ilk + son);
  }

  ProUsta copyWith({
    String? ad,
    String? unvan,
    bool unvanSil = false,
    String? fotoUrl,
    bool fotoSil = false,
    List<String>? uzmanlik,
    bool? aktif,
    int? sira,
    String? kullaniciId,
    bool hesapSil = false,
  }) {
    return ProUsta(
      id: id,
      ad: ad ?? this.ad,
      unvan: unvanSil ? null : (unvan ?? this.unvan),
      fotoUrl: fotoSil ? null : (fotoUrl ?? this.fotoUrl),
      uzmanlik: uzmanlik ?? this.uzmanlik,
      aktif: aktif ?? this.aktif,
      sira: sira ?? this.sira,
      kullaniciId: hesapSil ? null : (kullaniciId ?? this.kullaniciId),
    );
  }
}

/// Hazır berber menüsünden bir kalem.
@immutable
class HizmetSablonu {
  const HizmetSablonu(this.ad, this.kategori, this.sureDk);

  final String ad;
  final HizmetKategorisi kategori;
  final int sureDk;

  static const List<HizmetSablonu> berber = <HizmetSablonu>[
    HizmetSablonu('Saç kesimi', HizmetKategorisi.sac, 30),
    HizmetSablonu('Saç ve sakal', HizmetKategorisi.sac, 45),
    HizmetSablonu('Saç yıkama ve fön', HizmetKategorisi.sac, 15),
    HizmetSablonu('Sakal tıraşı', HizmetKategorisi.sakal, 20),
    HizmetSablonu('Ustura ile tıraş', HizmetKategorisi.sakal, 30),
    HizmetSablonu('Sakal şekillendirme', HizmetKategorisi.sakal, 20),
    HizmetSablonu('Saç boyama', HizmetKategorisi.renk, 60),
    HizmetSablonu('Sakal boyama', HizmetKategorisi.renk, 30),
    HizmetSablonu('Cilt bakımı', HizmetKategorisi.bakim, 30),
    HizmetSablonu('Kaş düzeltme', HizmetKategorisi.bakim, 10),
    HizmetSablonu('Ağda (kulak, burun)', HizmetKategorisi.bakim, 10),
    HizmetSablonu('Çocuk saç kesimi', HizmetKategorisi.cocuk, 20),
    HizmetSablonu('Damat tıraşı', HizmetKategorisi.diger, 90),
  ];
}

/// Uzmanlık önerileri (usta kartında etiket olarak görünür).
const List<String> uzmanlikOnerileri = <String>[
  'Fade',
  'Klasik kesim',
  'Makas kesim',
  'Sakal tasarımı',
  'Ustura',
  'Renk',
  'Perma',
  'Uzun saç',
  'Çocuk',
  'Damat',
];
