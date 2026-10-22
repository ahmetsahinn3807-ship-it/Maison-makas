import 'package:flutter/widgets.dart';

import 'dil.dart';

/// Bir paletin vurgu rengi seçeneği (ör. Altın, Şampanya).
@immutable
class MaisonVurgu {
  const MaisonVurgu(this._tr, this._en, this.renk);

  final String _tr;
  final String _en;
  final Color renk;

  /// Ekranda görünen ad (seçili dilde).
  String get ad => dl(_tr, _en);
}

/// Kullanıcının seçebildiği beş hazır görünümden biri.
///
/// Değerler tasarım dosyasındaki "Görünüm" ekranıyla birebir aynıdır.
@immutable
class MaisonPalet {
  const MaisonPalet({
    required this.kimlik,
    required this.ad,
    required this.koyu,
    required this.zemin,
    required this.kart,
    required this.yazi,
    required this.soluk,
    required this.cizgi,
    required this.vurguUstu,
    required this.kapaliIz,
    required this.kapaliTopuz,
    required this.vurgular,
  });

  /// Kayıt için kalıcı kimlik (ör. `noir-dore`).
  final String kimlik;

  /// Ekranda görünen ad.
  final String ad;

  /// Koyu zeminli mi?
  final bool koyu;

  final Color zemin;
  final Color kart;
  final Color yazi;
  final Color soluk;
  final Color cizgi;

  /// Vurgu renginin üstündeki yazı/ikon rengi.
  final Color vurguUstu;

  /// Kapalı anahtarın izi ve topuzu.
  final Color kapaliIz;
  final Color kapaliTopuz;

  /// İlk sıradaki varsayılan vurgudur.
  final List<MaisonVurgu> vurgular;

  /// Varsayılan vurgu rengi.
  Color get vurgu => vurgular.first.renk;

  /// Metin alanlarının zemini.
  Color get girdi => Color.lerp(zemin, kart, koyu ? 0.4 : 1.0)!;

  /// Soldan açılan menünün zemini.
  Color get menu => Color.lerp(zemin, kart, koyu ? 0.12 : 0.6)!;

  /// Kapak fotoğrafı yokken kullanılan sıcak ton.
  Color get kapak => koyu
      ? Color.lerp(zemin, const Color(0xFF3A3228), 0.45)!
      : Color.lerp(zemin, const Color(0xFFD9CDB8), 0.5)!;

  static const MaisonPalet noirDore = MaisonPalet(
    kimlik: 'noir-dore',
    ad: 'Noir Doré',
    koyu: true,
    zemin: Color(0xFF0E0E10),
    kart: Color(0xFF1F1F23),
    yazi: Color(0xFFF4F1EA),
    soluk: Color(0xFFA39E94),
    cizgi: Color(0xFF2C2C31),
    vurguUstu: Color(0xFF0E0E10),
    kapaliIz: Color(0xFF34343A),
    kapaliTopuz: Color(0xFFA39E94),
    vurgular: <MaisonVurgu>[
      MaisonVurgu('Altın', 'Gold', Color(0xFFC9A96E)),
      MaisonVurgu('Şampanya', 'Champagne', Color(0xFFD6BE96)),
      MaisonVurgu('Gül altını', 'Rose gold', Color(0xFFD4A08A)),
      MaisonVurgu('Buz mavisi', 'Ice blue', Color(0xFF8FB8C9)),
    ],
  );

  static const MaisonPalet ivoire = MaisonPalet(
    kimlik: 'ivoire',
    ad: 'Ivoire',
    koyu: false,
    zemin: Color(0xFFF7F3EC),
    kart: Color(0xFFFFFFFF),
    yazi: Color(0xFF1C1B19),
    soluk: Color(0xFF6B655C),
    cizgi: Color(0xFFE7E0D4),
    vurguUstu: Color(0xFFFFFFFF),
    kapaliIz: Color(0xFFDDD5C8),
    kapaliTopuz: Color(0xFFFFFFFF),
    vurgular: <MaisonVurgu>[
      MaisonVurgu('Bronz', 'Bronze', Color(0xFF7A5C34)),
      MaisonVurgu('Berber yeşili', 'Barber green', Color(0xFF1F4D3A)),
      MaisonVurgu('Bordo', 'Burgundy', Color(0xFF7A2E3A)),
      MaisonVurgu('Lacivert', 'Navy', Color(0xFF1F3A5F)),
    ],
  );

  static const MaisonPalet bordeaux = MaisonPalet(
    kimlik: 'bordeaux',
    ad: 'Bordeaux',
    koyu: true,
    zemin: Color(0xFF1B1013),
    kart: Color(0xFF261519),
    yazi: Color(0xFFF3E9E2),
    soluk: Color(0xFFB8A49C),
    cizgi: Color(0xFF3A2328),
    vurguUstu: Color(0xFF1B1013),
    kapaliIz: Color(0xFF43292F),
    kapaliTopuz: Color(0xFFB8A49C),
    vurgular: <MaisonVurgu>[
      MaisonVurgu('Şampanya', 'Champagne', Color(0xFFD6BE96)),
      MaisonVurgu('Altın', 'Gold', Color(0xFFC9A96E)),
      MaisonVurgu('Pudra', 'Powder pink', Color(0xFFE0B4A8)),
      MaisonVurgu('Adaçayı', 'Sage', Color(0xFFB9C7B0)),
    ],
  );

  static const MaisonPalet riviera = MaisonPalet(
    kimlik: 'riviera',
    ad: 'Riviera',
    koyu: false,
    zemin: Color(0xFFF5F7F8),
    kart: Color(0xFFFFFFFF),
    yazi: Color(0xFF0F2A3D),
    soluk: Color(0xFF55687A),
    cizgi: Color(0xFFDDE4EA),
    vurguUstu: Color(0xFFFFFFFF),
    kapaliIz: Color(0xFFD3DCE3),
    kapaliTopuz: Color(0xFFFFFFFF),
    vurgular: <MaisonVurgu>[
      MaisonVurgu('Akdeniz mavisi', 'Mediterranean blue', Color(0xFF1F6F8B)),
      MaisonVurgu('Deniz yeşili', 'Sea green', Color(0xFF2F5D50)),
      MaisonVurgu('Terrakota', 'Terracotta', Color(0xFF8A4B2F)),
      MaisonVurgu('Mor', 'Purple', Color(0xFF4B3F72)),
    ],
  );

  static const MaisonPalet barbiere = MaisonPalet(
    kimlik: 'barbiere',
    ad: 'Barbiere',
    koyu: false,
    zemin: Color(0xFFF2EDE3),
    kart: Color(0xFFFFFFFF),
    yazi: Color(0xFF1C1C1A),
    soluk: Color(0xFF66625A),
    cizgi: Color(0xFFE3DCCD),
    vurguUstu: Color(0xFFFFFFFF),
    kapaliIz: Color(0xFFDAD2C2),
    kapaliTopuz: Color(0xFFFFFFFF),
    vurgular: <MaisonVurgu>[
      MaisonVurgu('Berber yeşili', 'Barber green', Color(0xFF1F4D3A)),
      MaisonVurgu('Bronz', 'Bronze', Color(0xFF7A5C34)),
      MaisonVurgu('Bordo', 'Burgundy', Color(0xFF7A2E3A)),
      MaisonVurgu('Lacivert', 'Navy', Color(0xFF1F3A5F)),
    ],
  );

  /// Seçim ekranlarındaki sırayla tüm paletler.
  static const List<MaisonPalet> tumu = <MaisonPalet>[
    noirDore,
    ivoire,
    bordeaux,
    riviera,
    barbiere,
  ];

  /// Kayıtlı kimlikten paleti bulur; bulamazsa Noir Doré döner.
  static MaisonPalet kimliktenBul(String? kimlik) {
    for (final MaisonPalet palet in tumu) {
      if (palet.kimlik == kimlik) {
        return palet;
      }
    }
    return noirDore;
  }
}
