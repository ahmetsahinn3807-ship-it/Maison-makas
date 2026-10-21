import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../veri.dart';

/// Salonun vitrini: kapak, logo, eylemler ve Hizmetler · Galeri · Ekip · Yorumlar.
/// Randevu alma 21. adımda gelir; o zamana kadar düğme salonu aramayı önerir.
class SalonEkrani extends StatelessWidget {
  const SalonEkrani({super.key, required this.salon, this.kahramanEtiketi});

  final SalonOzet salon;

  /// Karttaki kapakla aynı etiket; kapak büyüyerek vitrine geçer.
  final String? kahramanEtiketi;

  void _randevuYakinda(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Online randevu çok yakında',
                  style: maisonBaslik(26, renk: r.yazi, kalinlik: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Salonun boş saatlerini görüp tek dokunuşla randevu alabileceksin. '
                  'Şimdilik vitrindeki Ara ya da Mesaj düğmesiyle salona ulaşabilirsin.',
                  style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tamam'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaisonVitrinEkrani(
      salon: salon.vitrin,
      kahramanEtiketi: kahramanEtiketi,
      onRandevu: () => _randevuYakinda(context),
    );
  }
}
