import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dil.dart';
import 'palet.dart';

/// Vitrin filtresi: salonun bütün fotoğraflarına tek dokunuşla aynı renk ayarı.
///
/// Fotoğrafların kendisi değişmez; filtre gösterilirken uygulanır, istenince kaldırılır.
/// Matrisler 4 × 5'tir; son sütun 0–255 aralığında eklenen değerdir.
enum VitrinFiltresi {
  dogal('Doğal', 'Natural'),
  sicak('Sıcak', 'Warm'),
  kehribar('Kehribar', 'Amber'),
  soguk('Soğuk', 'Cool'),
  mat('Mat', 'Matte'),
  siyahBeyaz('Siyah-beyaz', 'Black & white'),
  sepya('Sepya', 'Sepia');

  const VitrinFiltresi(this._tr, this._en);

  final String _tr;
  final String _en;

  /// Ekranda görünen ad (seçili dilde).
  String get ad => dl(_tr, _en);

  /// Kayıttaki addan filtreyi bulur; bulamazsa doğal.
  static VitrinFiltresi kimliktenBul(Object? kimlik) {
    for (final VitrinFiltresi f in VitrinFiltresi.values) {
      if (f.name == kimlik) {
        return f;
      }
    }
    return VitrinFiltresi.dogal;
  }

  /// Renk matrisi; doğal için null (filtre uygulanmaz).
  List<double>? get matris {
    switch (this) {
      case VitrinFiltresi.dogal:
        return null;
      case VitrinFiltresi.sicak:
        return const <double>[
          1.06, 0.02, 0.0, 0.0, 6.0, //
          0.01, 1.01, 0.0, 0.0, 2.0, //
          0.0, 0.0, 0.92, 0.0, -4.0, //
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
      case VitrinFiltresi.kehribar:
        return const <double>[
          1.10, 0.05, 0.0, 0.0, 10.0, //
          0.02, 1.0, 0.0, 0.0, 4.0, //
          0.0, 0.0, 0.82, 0.0, 0.0, //
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
      case VitrinFiltresi.soguk:
        return const <double>[
          0.94, 0.0, 0.0, 0.0, -2.0, //
          0.0, 1.0, 0.02, 0.0, 2.0, //
          0.0, 0.02, 1.08, 0.0, 8.0, //
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
      case VitrinFiltresi.mat:
        return const <double>[
          0.776, 0.094, 0.010, 0.0, 23.0, //
          0.028, 0.842, 0.010, 0.0, 23.0, //
          0.028, 0.094, 0.757, 0.0, 23.0, //
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
      case VitrinFiltresi.siyahBeyaz:
        return const <double>[
          0.2339, 0.7867, 0.0794, 0.0, -12.8, //
          0.2339, 0.7867, 0.0794, 0.0, -12.8, //
          0.2339, 0.7867, 0.0794, 0.0, -12.8, //
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
      case VitrinFiltresi.sepya:
        return const <double>[
          0.5751, 0.5383, 0.1323, 0.0, 0.0, //
          0.2443, 0.7802, 0.1176, 0.0, 0.0, //
          0.1904, 0.3738, 0.3917, 0.0, 0.0, //
          0.0, 0.0, 0.0, 1.0, 0.0,
        ];
    }
  }

  /// Filtreyi uygulayan renk süzgeci; doğal için null.
  ColorFilter? get suzgec {
    final List<double>? m = matris;
    return m == null ? null : ColorFilter.matrix(m);
  }
}

/// Salonun vitrin ayarları (`salonlar.vitrin`): tema, vurgu rengi ve fotoğraf filtresi.
@immutable
class VitrinAyari {
  const VitrinAyari({
    this.paletKimligi = 'noir-dore',
    this.vurgu = 0,
    this.filtre = VitrinFiltresi.dogal,
  });

  /// Veritabanındaki JSON'dan okur; eksik ya da bozuk alanlarda varsayılanı kullanır.
  factory VitrinAyari.json(Object? kaynak) {
    if (kaynak is! Map) {
      return const VitrinAyari();
    }
    final Object? tema = kaynak['tema'];
    final Object? vurgu = kaynak['vurgu'];
    return VitrinAyari(
      paletKimligi: tema is String && tema.isNotEmpty ? tema : 'noir-dore',
      vurgu: vurgu is num ? vurgu.toInt() : 0,
      filtre: VitrinFiltresi.kimliktenBul(kaynak['filtre']),
    );
  }

  final String paletKimligi;
  final int vurgu;
  final VitrinFiltresi filtre;

  MaisonPalet get palet => MaisonPalet.kimliktenBul(paletKimligi);

  /// Paletin seçili vurgu rengi (sıra dışındaysa ilk renk).
  Color get vurguRengi {
    final List<MaisonVurgu> secenekler = palet.vurgular;
    final int sira = math.min(math.max(vurgu, 0), secenekler.length - 1);
    return secenekler[sira].renk;
  }

  Map<String, dynamic> json() => <String, dynamic>{
        'tema': paletKimligi,
        'vurgu': vurgu,
        'filtre': filtre.name,
      };

  VitrinAyari copyWith({String? paletKimligi, int? vurgu, VitrinFiltresi? filtre}) {
    return VitrinAyari(
      paletKimligi: paletKimligi ?? this.paletKimligi,
      vurgu: vurgu ?? this.vurgu,
      filtre: filtre ?? this.filtre,
    );
  }
}
