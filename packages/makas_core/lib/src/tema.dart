import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palet.dart';
import 'renkler.dart';

/// Gövde yazı tipi: Inter (paketle birlikte gelir).
const String kGovdeYaziTipi = 'packages/makas_core/Inter';

/// Başlık yazı tipi: Cormorant Garamond (paketle birlikte gelir).
const String kBaslikYaziTipi = 'packages/makas_core/Cormorant';

/// Cormorant Garamond ile başlık stili.
TextStyle maisonBaslik(
  double boyut, {
  Color? renk,
  FontWeight kalinlik = FontWeight.w500,
  FontStyle bicim = FontStyle.normal,
  double yukseklik = 1.1,
  double? aralik,
}) {
  return TextStyle(
    fontFamily: kBaslikYaziTipi,
    fontSize: boyut,
    fontWeight: kalinlik,
    fontStyle: bicim,
    height: yukseklik,
    letterSpacing: aralik,
    color: renk,
  );
}

/// Inter ile gövde stili.
TextStyle maisonGovde(
  double boyut, {
  Color? renk,
  FontWeight kalinlik = FontWeight.w400,
  double yukseklik = 1.45,
  double? aralik,
}) {
  return TextStyle(
    fontFamily: kGovdeYaziTipi,
    fontSize: boyut,
    fontWeight: kalinlik,
    height: yukseklik,
    letterSpacing: aralik,
    color: renk,
  );
}

/// Seçilen palet ve vurgu renginden uygulamanın temasını üretir.
ThemeData maisonTemasi(MaisonPalet palet, {Color? vurgu}) {
  final Color v = vurgu ?? palet.vurgu;

  final ColorScheme sema = ColorScheme(
    brightness: palet.koyu ? Brightness.dark : Brightness.light,
    primary: v,
    onPrimary: palet.vurguUstu,
    secondary: v,
    onSecondary: palet.vurguUstu,
    tertiary: v,
    onTertiary: palet.vurguUstu,
    error: palet.koyu ? const Color(0xFFE5897F) : const Color(0xFFB3261E),
    onError: palet.koyu ? const Color(0xFF2B0A07) : const Color(0xFFFFFFFF),
    surface: palet.zemin,
    onSurface: palet.yazi,
    onSurfaceVariant: palet.soluk,
    surfaceContainerLowest: palet.zemin,
    surfaceContainerLow: palet.kart,
    surfaceContainer: palet.kart,
    surfaceContainerHigh: palet.kart,
    surfaceContainerHighest: palet.kart,
    outline: palet.cizgi,
    outlineVariant: palet.cizgi,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    inverseSurface: palet.yazi,
    onInverseSurface: palet.zemin,
    inversePrimary: v,
    surfaceTint: const Color(0x00000000),
  );

  final TextTheme yazilar = TextTheme(
    displayLarge: maisonBaslik(57, renk: palet.yazi, yukseklik: 1.0),
    displayMedium: maisonBaslik(45, renk: palet.yazi, yukseklik: 1.0),
    displaySmall: maisonBaslik(36, renk: palet.yazi, yukseklik: 1.05),
    headlineLarge: maisonBaslik(32, renk: palet.yazi),
    headlineMedium: maisonBaslik(28, renk: palet.yazi),
    headlineSmall: maisonBaslik(24, renk: palet.yazi),
    titleLarge: maisonGovde(18, renk: palet.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
    titleMedium: maisonGovde(16, renk: palet.yazi, kalinlik: FontWeight.w600, yukseklik: 1.35),
    titleSmall: maisonGovde(14, renk: palet.yazi, kalinlik: FontWeight.w600, yukseklik: 1.35),
    bodyLarge: maisonGovde(16, renk: palet.yazi, yukseklik: 1.5),
    bodyMedium: maisonGovde(15, renk: palet.yazi, yukseklik: 1.5),
    bodySmall: maisonGovde(13, renk: palet.soluk),
    labelLarge: maisonGovde(15, renk: palet.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
    labelMedium: maisonGovde(13, renk: palet.yazi, kalinlik: FontWeight.w500, yukseklik: 1.2),
    labelSmall: maisonGovde(11, renk: palet.soluk, kalinlik: FontWeight.w600, yukseklik: 1.2, aralik: 1.6),
  );

  return ThemeData(
    colorScheme: sema,
    scaffoldBackgroundColor: palet.zemin,
    textTheme: yazilar,
    extensions: <ThemeExtension<dynamic>>[MaisonRenkler.paletten(palet, v)],
    splashFactory: InkRipple.splashFactory,
    dividerTheme: DividerThemeData(color: palet.cizgi, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: v,
        foregroundColor: palet.vurguUstu,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: maisonGovde(16, kalinlik: FontWeight.w600, yukseklik: 1.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palet.yazi,
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        side: BorderSide(color: palet.cizgi),
        textStyle: maisonGovde(15, kalinlik: FontWeight.w500, yukseklik: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: v,
        textStyle: maisonGovde(14, kalinlik: FontWeight.w500, yukseklik: 1.2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palet.kart,
      contentTextStyle: maisonGovde(14, renk: palet.yazi),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palet.cizgi),
      ),
    ),
  );
}

/// Durum ve gezinme çubuğunu palete uydurur (koyu zeminde açık ikonlar).
SystemUiOverlayStyle maisonSistemCubugu(MaisonPalet palet) {
  final SystemUiOverlayStyle temel =
      palet.koyu ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
  return temel.copyWith(
    statusBarColor: const Color(0x00000000),
    systemNavigationBarColor: palet.zemin,
    systemNavigationBarDividerColor: palet.zemin,
    systemNavigationBarIconBrightness: palet.koyu ? Brightness.light : Brightness.dark,
  );
}
