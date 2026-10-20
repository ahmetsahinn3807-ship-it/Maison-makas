import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:makas_core/makas_core.dart';

import 'dil.dart';

/// Kullanıcının seçtiği görünüm: palet, vurgu rengi, koyu mod ve dil.
///
/// Giriş yapılmışsa değişiklikler kısa bir gecikmeyle hesaba kaydedilir;
/// telefon değişse de görünüm aynı kalır.
class Gorunum extends ChangeNotifier {
  Gorunum({this.kaydet});

  /// Ayarları hesaba yazar; yoksa (testler, giriş yapılmamış) yalnız bellekte tutulur.
  final Future<void> Function(Map<String, dynamic> alanlar)? kaydet;

  MaisonPalet _palet = MaisonPalet.noirDore;
  int _vurguSirasi = 0;
  Dil _dil = Dil.tr;
  MaisonPalet _sonKoyu = MaisonPalet.noirDore;
  MaisonPalet _sonAcik = MaisonPalet.ivoire;
  Timer? _zamanlayici;

  MaisonPalet get palet => _palet;
  int get vurguSirasi => math.min(math.max(_vurguSirasi, 0), _palet.vurgular.length - 1);
  Color get vurgu => _palet.vurgular[vurguSirasi].renk;
  bool get koyu => _palet.koyu;
  Dil get dil => _dil;
  Metinler get metin => Metinler.dilIcin(_dil);

  /// Hesapta saklanan biçim.
  Map<String, dynamic> get kayit => <String, dynamic>{
        'palet': _palet.kimlik,
        'vurgu': vurguSirasi,
        'son_koyu': _sonKoyu.kimlik,
        'son_acik': _sonAcik.kimlik,
      };

  void paletSec(MaisonPalet palet) {
    if (identical(palet, _palet)) {
      return;
    }
    _palet = palet;
    _vurguSirasi = 0;
    if (palet.koyu) {
      _sonKoyu = palet;
    } else {
      _sonAcik = palet;
    }
    _degisti();
  }

  void vurguSec(int sira) {
    if (sira == _vurguSirasi) {
      return;
    }
    _vurguSirasi = sira;
    _degisti();
  }

  /// Koyu mod açılınca son kullanılan koyu palete, kapanınca son açık palete geçer.
  void koyuModAyarla(bool acik) {
    if (acik == _palet.koyu) {
      return;
    }
    paletSec(acik ? _sonKoyu : _sonAcik);
  }

  void dilSec(Dil dil) {
    if (dil == _dil) {
      return;
    }
    _dil = dil;
    _degisti();
  }

  /// Hesaptan gelen ayarları uygular; tekrar kaydetmez.
  void uygula(Object? kayit, Object? dil) {
    if (kayit is Map) {
      final Object? p = kayit['palet'];
      final Object? v = kayit['vurgu'];
      final Object? sk = kayit['son_koyu'];
      final Object? sa = kayit['son_acik'];
      if (p is String) {
        _palet = MaisonPalet.kimliktenBul(p);
      }
      if (v is int) {
        _vurguSirasi = v;
      }
      if (sk is String) {
        _sonKoyu = MaisonPalet.kimliktenBul(sk);
      }
      if (sa is String) {
        _sonAcik = MaisonPalet.kimliktenBul(sa);
      }
    }
    if (dil is String) {
      for (final Dil d in Dil.values) {
        if (d.name == dil) {
          _dil = d;
        }
      }
    }
    notifyListeners();
  }

  void _degisti() {
    notifyListeners();
    if (kaydet == null) {
      return;
    }
    _zamanlayici?.cancel();
    _zamanlayici = Timer(const Duration(milliseconds: 800), _kaydetSimdi);
  }

  Future<void> _kaydetSimdi() async {
    final Future<void> Function(Map<String, dynamic> alanlar)? f = kaydet;
    if (f == null) {
      return;
    }
    try {
      await f(<String, dynamic>{'gorunum': kayit, 'dil': _dil.name});
    } catch (_) {
      // Bağlantı yoksa ayar bir sonraki değişiklikte yeniden kaydedilir.
    }
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }
}

/// [Gorunum] nesnesini alt ağaca taşır; değiştiğinde bağımlıları yeniden çizer.
class GorunumKapsami extends InheritedNotifier<Gorunum> {
  const GorunumKapsami({
    super.key,
    required Gorunum gorunum,
    required super.child,
  }) : super(notifier: gorunum);

  static Gorunum of(BuildContext context) {
    final GorunumKapsami? kapsam =
        context.dependOnInheritedWidgetOfExactType<GorunumKapsami>();
    assert(kapsam != null, 'GorunumKapsami bulunamadı.');
    return kapsam!.notifier!;
  }
}
