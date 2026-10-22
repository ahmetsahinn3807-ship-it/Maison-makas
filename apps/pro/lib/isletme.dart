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
  const HizmetSablonu(this._tr, this._en, this.kategori, this.sureDk);

  final String _tr;
  final String _en;

  /// Seçili dilde ad; salona bu adla eklenir.
  String get ad => dl(_tr, _en);

  final HizmetKategorisi kategori;
  final int sureDk;

  static const List<HizmetSablonu> berber = <HizmetSablonu>[
    HizmetSablonu('Saç kesimi', 'Haircut', HizmetKategorisi.sac, 30),
    HizmetSablonu('Saç ve sakal', 'Hair and beard', HizmetKategorisi.sac, 45),
    HizmetSablonu('Saç yıkama ve fön', 'Wash and blow-dry', HizmetKategorisi.sac, 15),
    HizmetSablonu('Sakal tıraşı', 'Beard shave', HizmetKategorisi.sakal, 20),
    HizmetSablonu('Ustura ile tıraş', 'Straight razor shave', HizmetKategorisi.sakal, 30),
    HizmetSablonu('Sakal şekillendirme', 'Beard shaping', HizmetKategorisi.sakal, 20),
    HizmetSablonu('Saç boyama', 'Hair colouring', HizmetKategorisi.renk, 60),
    HizmetSablonu('Sakal boyama', 'Beard colouring', HizmetKategorisi.renk, 30),
    HizmetSablonu('Cilt bakımı', 'Skin care', HizmetKategorisi.bakim, 30),
    HizmetSablonu('Kaş düzeltme', 'Eyebrow tidy', HizmetKategorisi.bakim, 10),
    HizmetSablonu('Ağda (kulak, burun)', 'Waxing (ears, nose)', HizmetKategorisi.bakim, 10),
    HizmetSablonu('Çocuk saç kesimi', "Kids' haircut", HizmetKategorisi.cocuk, 20),
    HizmetSablonu('Damat tıraşı', 'Groom shave', HizmetKategorisi.diger, 90),
  ];
}

/// Uzmanlık önerileri (usta kartında etiket olarak görünür; seçili dilde).
List<String> get uzmanlikOnerileri => <String>[
      'Fade',
      dl('Klasik kesim', 'Classic cut'),
      dl('Makas kesim', 'Scissor cut'),
      dl('Sakal tasarımı', 'Beard design'),
      dl('Ustura', 'Straight razor'),
      dl('Renk', 'Colour'),
      dl('Perma', 'Perm'),
      dl('Uzun saç', 'Long hair'),
      dl('Çocuk', 'Kids'),
      dl('Damat', 'Groom'),
    ];
