import 'package:flutter/widgets.dart';
import 'package:makas_core/makas_core.dart';

import 'dil.dart';

/// Kullanıcının seçtiği görünüm: palet, vurgu rengi ve dil.
///
/// Şimdilik bellekte tutulur; hesap gelince profile kaydedilecek.
class Gorunum extends ChangeNotifier {
  MaisonPalet _palet = MaisonPalet.noirDore;
  Color _vurgu = MaisonPalet.noirDore.vurgu;
  Dil _dil = Dil.tr;

  MaisonPalet get palet => _palet;
  Color get vurgu => _vurgu;
  Dil get dil => _dil;
  Metinler get metin => Metinler.dilIcin(_dil);

  void paletSec(MaisonPalet palet) {
    if (identical(palet, _palet)) return;
    _palet = palet;
    _vurgu = palet.vurgu;
    notifyListeners();
  }

  void vurguSec(Color vurgu) {
    if (vurgu == _vurgu) return;
    _vurgu = vurgu;
    notifyListeners();
  }

  void dilSec(Dil dil) {
    if (dil == _dil) return;
    _dil = dil;
    notifyListeners();
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
