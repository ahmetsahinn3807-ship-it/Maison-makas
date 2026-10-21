import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../salon.dart';

/// Bugün ekranında "Salonun randevuya hazır mı?" listesi. Hepsi tamamlanınca kendini gizler.
class HazirlikKarti extends StatefulWidget {
  const HazirlikKarti({
    super.key,
    required this.salon,
    required this.surum,
    required this.hizmetler,
    required this.ekip,
    required this.vitrin,
    required this.bilgiler,
    required this.ayarlar,
  });

  final ProSalon salon;

  /// Başka bir ekrandan dönülünce artar; liste yeniden okunur.
  final int surum;

  final VoidCallback hizmetler;
  final VoidCallback ekip;
  final VoidCallback vitrin;
  final VoidCallback bilgiler;
  final VoidCallback ayarlar;

  @override
  State<HazirlikKarti> createState() => _HazirlikKartiState();
}

class _HazirlikKartiState extends State<HazirlikKarti> {
  Map<String, dynamic>? _durum;
  bool _ilk = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ilk) {
      _ilk = false;
      _yukle();
    }
  }

  @override
  void didUpdateWidget(HazirlikKarti eski) {
    super.didUpdateWidget(eski);
    if (eski.surum != widget.surum || eski.salon.yayinda != widget.salon.yayinda) {
      _yukle();
    }
  }

  Future<void> _yukle() async {
    final SupabaseClient? i = OturumKapsami.oku(context).istemci;
    if (i == null) {
      return;
    }
    try {
      final Object? sonuc = await i.rpc('salon_hazirligi', params: <String, dynamic>{'p_salon': widget.salon.id});
      if (mounted && sonuc is Map<String, dynamic>) {
        setState(() => _durum = sonuc);
      }
    } catch (_) {
      // SQL kodu henüz çalıştırılmadıysa ya da bağlantı yoksa liste görünmez.
    }
  }

  int _sayi(Map<String, dynamic> d, String ad) => (d[ad] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? d = _durum;
    if (d == null) {
      return const SizedBox.shrink();
    }
    final MaisonRenkler r = MaisonRenkler.of(context);
    final int hizmet = _sayi(d, 'hizmet');
    final int usta = _sayi(d, 'usta');
    final int saatli = _sayi(d, 'saatli_usta');
    final bool kapak = d['kapak'] == true;
    final bool aciklama = d['aciklama'] == true;
    final bool yayinda = d['yayinda'] == true;
    final List<_Madde> maddeler = <_Madde>[
      _Madde(
        baslik: 'Hizmet menüsü',
        tamam: hizmet > 0,
        aciklama: hizmet > 0 ? '$hizmet hizmet' : 'Müşterilerin seçeceği hizmetleri ekle',
        onTap: widget.hizmetler,
      ),
      _Madde(
        baslik: 'Ekip',
        tamam: usta > 0,
        aciklama: usta > 0 ? '$usta usta' : 'Kendini ya da ustalarını ekle',
        onTap: widget.ekip,
      ),
      _Madde(
        baslik: 'Çalışma saatleri',
        tamam: usta > 0 && saatli >= usta,
        aciklama: usta == 0
            ? 'Önce ekibini kur'
            : saatli >= usta
                ? 'Bütün ustaların saatleri girildi'
                : '${usta - saatli} ustanın saati eksik',
        onTap: widget.ekip,
      ),
      _Madde(
        baslik: 'Vitrin',
        tamam: kapak,
        aciklama: kapak ? 'Kapak fotoğrafı eklendi' : 'Kapak fotoğrafı ve galeri ekle',
        onTap: widget.vitrin,
      ),
      _Madde(
        baslik: 'Salon tanıtımı',
        tamam: aciklama,
        aciklama: aciklama ? 'Tanıtım yazıldı' : 'Vitrinde görünecek birkaç cümle yaz',
        onTap: widget.bilgiler,
      ),
      _Madde(
        baslik: 'Yayına al',
        tamam: yayinda,
        aciklama: yayinda ? 'Salonun Keşfet\'te görünüyor' : 'Hazır olunca Ayarlar\'dan yayına al',
        onTap: widget.ayarlar,
      ),
    ];
    final int biten = maddeler.where((_Madde m) => m.tamam).length;
    if (biten == maddeler.length) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
        decoration: BoxDecoration(
          color: r.kart,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: r.cizgi),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: <Widget>[
                  const Expanded(child: MaisonUstBaslik('SALONUN RANDEVUYA HAZIR MI?')),
                  Text(
                    '$biten/${maddeler.length}',
                    style: maisonGovde(13, renk: r.vurgu, kalinlik: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: LinearProgressIndicator(
                value: biten / maddeler.length,
                minHeight: 4,
                color: r.vurgu,
                backgroundColor: r.cizgi,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            for (final _Madde m in maddeler) _MaddeSatiri(madde: m),
          ],
        ),
      ),
    );
  }
}

@immutable
class _Madde {
  const _Madde({required this.baslik, required this.tamam, required this.aciklama, required this.onTap});

  final String baslik;
  final bool tamam;
  final String aciklama;
  final VoidCallback onTap;
}

class _MaddeSatiri extends StatelessWidget {
  const _MaddeSatiri({required this.madde});

  final _Madde madde;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return InkWell(
      onTap: madde.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(
              madde.tamam ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: madde.tamam ? r.vurgu : r.soluk,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    madde.baslik,
                    style: maisonGovde(
                      15,
                      renk: madde.tamam ? r.soluk : r.yazi,
                      kalinlik: FontWeight.w600,
                      yukseklik: 1.3,
                    ),
                  ),
                  Text(madde.aciklama, style: maisonGovde(12, renk: r.soluk, yukseklik: 1.35)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: r.soluk.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
