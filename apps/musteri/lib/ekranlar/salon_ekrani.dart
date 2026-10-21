import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../veri.dart';
import 'randevu_akisi.dart';

/// Salonun vitrini: kapak, logo, eylemler ve Hizmetler · Galeri · Ekip · Yorumlar.
/// Randevu Al düğmesi randevu akışını açar.
class SalonEkrani extends StatelessWidget {
  const SalonEkrani({super.key, required this.salon, this.kahramanEtiketi});

  final SalonOzet salon;

  /// Karttaki kapakla aynı etiket; kapak büyüyerek vitrine geçer.
  final String? kahramanEtiketi;

  @override
  Widget build(BuildContext context) {
    return MaisonVitrinEkrani(
      salon: salon.vitrin,
      kahramanEtiketi: kahramanEtiketi,
      onRandevu: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => RandevuAkisi(salon: salon.vitrin),
        ),
      ),
    );
  }
}
