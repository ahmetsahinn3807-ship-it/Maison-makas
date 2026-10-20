import 'package:flutter/material.dart';

import 'palet.dart';

/// Seçili paletin renkleri; her ekran bunları `MaisonRenkler.of(context)` ile okur.
@immutable
class MaisonRenkler extends ThemeExtension<MaisonRenkler> {
  const MaisonRenkler({
    required this.koyu,
    required this.zemin,
    required this.kart,
    required this.girdi,
    required this.menu,
    required this.kapak,
    required this.yazi,
    required this.soluk,
    required this.cizgi,
    required this.vurgu,
    required this.vurguUstu,
  });

  factory MaisonRenkler.paletten(MaisonPalet palet, Color vurgu) {
    return MaisonRenkler(
      koyu: palet.koyu,
      zemin: palet.zemin,
      kart: palet.kart,
      girdi: palet.girdi,
      menu: palet.menu,
      kapak: palet.kapak,
      yazi: palet.yazi,
      soluk: palet.soluk,
      cizgi: palet.cizgi,
      vurgu: vurgu,
      vurguUstu: palet.vurguUstu,
    );
  }

  final bool koyu;
  final Color zemin;
  final Color kart;
  final Color girdi;
  final Color menu;
  final Color kapak;
  final Color yazi;
  final Color soluk;
  final Color cizgi;
  final Color vurgu;
  final Color vurguUstu;

  /// Vurgunun hafif dolgusu (seçili satır, rozet zemini).
  Color get vurguYumusak => vurgu.withValues(alpha: 0.14);

  /// Vurgunun ince çizgisi (kart kenarı, kemer çizgisi).
  Color get vurguCizgi => vurgu.withValues(alpha: 0.45);

  static MaisonRenkler of(BuildContext context) {
    return Theme.of(context).extension<MaisonRenkler>() ??
        MaisonRenkler.paletten(MaisonPalet.noirDore, MaisonPalet.noirDore.vurgu);
  }

  @override
  MaisonRenkler copyWith({
    bool? koyu,
    Color? zemin,
    Color? kart,
    Color? girdi,
    Color? menu,
    Color? kapak,
    Color? yazi,
    Color? soluk,
    Color? cizgi,
    Color? vurgu,
    Color? vurguUstu,
  }) {
    return MaisonRenkler(
      koyu: koyu ?? this.koyu,
      zemin: zemin ?? this.zemin,
      kart: kart ?? this.kart,
      girdi: girdi ?? this.girdi,
      menu: menu ?? this.menu,
      kapak: kapak ?? this.kapak,
      yazi: yazi ?? this.yazi,
      soluk: soluk ?? this.soluk,
      cizgi: cizgi ?? this.cizgi,
      vurgu: vurgu ?? this.vurgu,
      vurguUstu: vurguUstu ?? this.vurguUstu,
    );
  }

  @override
  MaisonRenkler lerp(covariant ThemeExtension<MaisonRenkler>? other, double t) {
    if (other is! MaisonRenkler) {
      return this;
    }
    return MaisonRenkler(
      koyu: t < 0.5 ? koyu : other.koyu,
      zemin: Color.lerp(zemin, other.zemin, t)!,
      kart: Color.lerp(kart, other.kart, t)!,
      girdi: Color.lerp(girdi, other.girdi, t)!,
      menu: Color.lerp(menu, other.menu, t)!,
      kapak: Color.lerp(kapak, other.kapak, t)!,
      yazi: Color.lerp(yazi, other.yazi, t)!,
      soluk: Color.lerp(soluk, other.soluk, t)!,
      cizgi: Color.lerp(cizgi, other.cizgi, t)!,
      vurgu: Color.lerp(vurgu, other.vurgu, t)!,
      vurguUstu: Color.lerp(vurguUstu, other.vurguUstu, t)!,
    );
  }
}
