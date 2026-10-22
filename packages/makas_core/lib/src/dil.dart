import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'oturum.dart';
import 'palet.dart';

/// Uygulamaların konuştuğu diller.
enum MaisonDil {
  tr('TR', 'Türkçe', Locale('tr')),
  en('EN', 'English', Locale('en'));

  const MaisonDil(this.kod, this.ad, this.yerel);

  /// Seçicide görünen kısa kod.
  final String kod;

  /// Dilin kendi dilindeki adı.
  final String ad;

  final Locale yerel;

  /// 'tr' / 'en' → dil; tanınmazsa null (ör. eski sürümlerden kalan 'de').
  static MaisonDil? addan(Object? ad) {
    for (final MaisonDil d in MaisonDil.values) {
      if (d.name == ad) {
        return d;
      }
    }
    return null;
  }
}

/// Yazı boyutu: telefonun kendi yazı boyutunun üstüne uygulanır.
enum MaisonYaziBoyutu {
  kucuk(0.9),
  normal(1.0),
  buyuk(1.15);

  const MaisonYaziBoyutu(this.oran);

  final double oran;

  String get ad {
    switch (this) {
      case MaisonYaziBoyutu.kucuk:
        return dl('Küçük', 'Small');
      case MaisonYaziBoyutu.normal:
        return dl('Normal', 'Normal');
      case MaisonYaziBoyutu.buyuk:
        return dl('Büyük', 'Large');
    }
  }

  static MaisonYaziBoyutu? addan(Object? ad) {
    for (final MaisonYaziBoyutu y in MaisonYaziBoyutu.values) {
      if (y.name == ad) {
        return y;
      }
    }
    return null;
  }
}

/// Dil ve yazı boyutu tercihleri. Telefonda saklanır; giriş ekranından önce de geçerlidir.
class MaisonTercih {
  MaisonTercih._();

  static final ValueNotifier<MaisonDil> dil = ValueNotifier<MaisonDil>(MaisonDil.tr);
  static final ValueNotifier<MaisonYaziBoyutu> yazi = ValueNotifier<MaisonYaziBoyutu>(MaisonYaziBoyutu.normal);

  /// Makas Pro'nun koyu görünümü (müşteri uygulamasının paletleri hesapta saklanır, bu değil).
  static final ValueNotifier<bool> koyu = ValueNotifier<bool>(false);

  static const String _dilAnahtari = 'maison.dil';
  static const String _yaziAnahtari = 'maison.yazi';
  static const String _koyuAnahtari = 'maison.koyu';

  /// Makas Pro'nun paleti: açıkta Ivoire, koyuda Noir Doré.
  static MaisonPalet get proPaleti => koyu.value ? MaisonPalet.noirDore : MaisonPalet.ivoire;

  static bool get ingilizce => dil.value == MaisonDil.en;

  /// Kullanıcı bu telefonda dil seçti mi? Seçmediyse girişte hesaptaki dil uygulanır.
  static bool dilSecildi = false;

  /// Material bileşenlerinin (tarih seçici, kopyala/yapıştır menüsü…) çevirileri.
  static const List<LocalizationsDelegate<dynamic>> yerellestirmeler = GlobalMaterialLocalizations.delegates;

  static final List<Locale> desteklenenler = <Locale>[for (final MaisonDil d in MaisonDil.values) d.yerel];

  /// Açılışta bir kez: kayıtlı tercih yoksa telefonun dili (Türkçe değilse İngilizce).
  static Future<void> yukle() async {
    dil.value = _telefonunDili();
    try {
      final SharedPreferences ayar = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      final MaisonDil? kayitli = MaisonDil.addan(ayar.getString(_dilAnahtari));
      if (kayitli != null) {
        dil.value = kayitli;
        dilSecildi = true;
      }
      yazi.value = MaisonYaziBoyutu.addan(ayar.getString(_yaziAnahtari)) ?? yazi.value;
      koyu.value = ayar.getBool(_koyuAnahtari) ?? koyu.value;
    } catch (_) {
      // Tercihler okunamazsa telefonun dili ve normal yazı boyutu kullanılır.
    }
  }

  static MaisonDil _telefonunDili() {
    try {
      final String kod = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      return kod == 'tr' ? MaisonDil.tr : MaisonDil.en;
    } catch (_) {
      return MaisonDil.tr;
    }
  }

  static void dilSec(MaisonDil yeni) {
    dilSecildi = true;
    unawaited(_sakla(_dilAnahtari, yeni.name));
    dil.value = yeni;
  }

  static void yaziSec(MaisonYaziBoyutu yeni) {
    if (yeni == yazi.value) {
      return;
    }
    yazi.value = yeni;
    unawaited(_sakla(_yaziAnahtari, yeni.name));
  }

  static void koyuAyarla(bool acik) {
    if (acik == koyu.value) {
      return;
    }
    koyu.value = acik;
    unawaited(_sakla(_koyuAnahtari, acik));
  }

  static Future<void> _sakla(String anahtar, Object deger) async {
    try {
      final SharedPreferences ayar = await SharedPreferences.getInstance().timeout(const Duration(seconds: 3));
      if (deger is bool) {
        await ayar.setBool(anahtar, deger);
      } else {
        await ayar.setString(anahtar, deger.toString());
      }
    } catch (_) {
      // Saklanamazsa tercih yalnız bu açılışta geçerli olur.
    }
  }
}

/// Seçili dile göre metin: `dl('Randevu al', 'Book')`.
String dl(String turkce, String ingilizce) => MaisonTercih.dil.value == MaisonDil.en ? ingilizce : turkce;

/// MaterialApp.builder içine konur: yazı boyutunu uygular, dil değişince bütün ekranları yeniden çizer
/// (açık sayfalar ve yazılanlar korunur).
class MaisonTercihKatmani extends StatefulWidget {
  const MaisonTercihKatmani({super.key, required this.child});

  final Widget? child;

  @override
  State<MaisonTercihKatmani> createState() => _MaisonTercihKatmaniState();
}

class _MaisonTercihKatmaniState extends State<MaisonTercihKatmani> {
  @override
  void initState() {
    super.initState();
    MaisonTercih.dil.addListener(_dilDegisti);
    MaisonTercih.yazi.addListener(_yaziDegisti);
  }

  @override
  void dispose() {
    MaisonTercih.dil.removeListener(_dilDegisti);
    MaisonTercih.yazi.removeListener(_yaziDegisti);
    super.dispose();
  }

  void _dilDegisti() {
    if (!mounted) {
      return;
    }
    void yenile(Element e) {
      e.markNeedsBuild();
      e.visitChildren(yenile);
    }

    (context as Element).visitChildren(yenile);
  }

  void _yaziDegisti() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget icerik = widget.child ?? const SizedBox.shrink();
    final MediaQueryData? mq = MediaQuery.maybeOf(context);
    if (mq == null) {
      return icerik;
    }
    final double sistem = mq.textScaler.scale(16) / 16;
    final double oran = (sistem * MaisonTercih.yazi.value.oran).clamp(0.8, 1.6).toDouble();
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(oran)),
      child: icerik,
    );
  }
}

/// Dil tercihini hesapla eşitler (profiller.dil). Uygulamanın kökünde bir kez kurulur.
///
/// Girişte: kullanıcı bu telefonda dil seçtiyse o hesaba yazılır; seçmediyse hesaptaki dil uygulanır
/// (ör. yeni telefon). Sonraki her dil değişikliği hesaba yazılır.
class MaisonDilEsitleyici {
  MaisonDilEsitleyici(this.oturum) {
    oturum.addListener(_oturumDegisti);
    MaisonTercih.dil.addListener(_dilDegisti);
    _oturumDegisti();
  }

  final MaisonOturum oturum;
  String? _kullanici;
  bool _uyguluyor = false;

  void _oturumDegisti() {
    if (!oturum.girisli) {
      _kullanici = null;
      return;
    }
    final Map<String, dynamic>? profil = oturum.profil;
    final Object? id = profil?['id'];
    if (profil == null || id is! String || id == _kullanici) {
      return;
    }
    _kullanici = id;
    final MaisonDil? hesaptaki = MaisonDil.addan(profil['dil']);
    if (MaisonTercih.dilSecildi || hesaptaki == null) {
      if (hesaptaki != MaisonTercih.dil.value) {
        unawaited(_kaydet());
      }
      return;
    }
    if (hesaptaki != MaisonTercih.dil.value) {
      _uyguluyor = true;
      MaisonTercih.dil.value = hesaptaki;
      _uyguluyor = false;
    }
  }

  void _dilDegisti() {
    if (!_uyguluyor && oturum.girisli) {
      unawaited(_kaydet());
    }
  }

  Future<void> _kaydet() async {
    try {
      await oturum.profilGuncelle(<String, dynamic>{'dil': MaisonTercih.dil.value.name});
    } catch (_) {
      // Bağlantı yoksa dil bu telefonda yine geçerlidir; bir sonraki değişiklikte yazılır.
    }
  }

  void kapat() {
    oturum.removeListener(_oturumDegisti);
    MaisonTercih.dil.removeListener(_dilDegisti);
  }
}
