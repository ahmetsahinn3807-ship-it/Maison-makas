import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';

void main() {
  runApp(const MakasProUygulamasi());
}

/// Makas Pro — salon sahipleri ve ustalar için işletme uygulaması.
class MakasProUygulamasi extends StatelessWidget {
  const MakasProUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makas Pro',
      debugShowCheckedModeBanner: false,
      theme: maisonTemasi(MaisonPalet.ivoire),
      home: const ProKarsilama(),
    );
  }
}

/// İlk derlemenin karşılama sayfası.
class ProKarsilama extends StatelessWidget {
  const ProKarsilama({super.key});

  static const List<_Modul> _moduller = <_Modul>[
    _Modul(Icons.today_outlined, 'Bugün', 'Günün randevuları tek bakışta'),
    _Modul(Icons.calendar_month_outlined, 'Takvim', 'Haftalık görünüm, boş saatler'),
    _Modul(Icons.groups_outlined, 'Ekip', 'Ustalar, çalışma saatleri, izinler'),
    _Modul(Icons.content_cut, 'Hizmetler', 'Süre ve fiyat listesi'),
    _Modul(Icons.storefront_outlined, 'Vitrin', 'Profil, duvar fotoğrafı, galeri'),
    _Modul(Icons.insights_outlined, 'Kazanç', 'Günlük ve aylık özet'),
  ];

  @override
  Widget build(BuildContext context) {
    const MaisonPalet palet = MaisonPalet.ivoire;
    final Color vurgu = palet.vurgu;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(palet),
      child: Scaffold(
        backgroundColor: palet.zemin,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  MaisonAmblem(renk: vurgu, zemin: palet.zemin, genislik: 46),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'MAISON MAKAS',
                          style: maisonGovde(
                            11,
                            renk: vurgu,
                            kalinlik: FontWeight.w600,
                            aralik: 2.6,
                          ),
                        ),
                        Text(
                          'Pro',
                          style: maisonBaslik(56, renk: palet.yazi, yukseklik: 1.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'İşletme paneli',
                style: maisonBaslik(
                  26,
                  renk: palet.yazi,
                  bicim: FontStyle.italic,
                  yukseklik: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu ilk derleme marka ve altyapıyı doğruluyor. Salonunu yöneteceğin ekranlar sıradaki adımlarda bu uygulamaya eklenecek.',
                style: maisonGovde(15, renk: palet.soluk, yukseklik: 1.55),
              ),
              const SizedBox(height: 28),
              Text(
                'MODÜLLER',
                style: maisonGovde(
                  11,
                  renk: palet.soluk,
                  kalinlik: FontWeight.w600,
                  aralik: 2.2,
                ),
              ),
              const SizedBox(height: 12),
              for (final _Modul modul in _moduller)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ModulKarti(modul: modul, palet: palet, vurgu: vurgu),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _Modul {
  const _Modul(this.ikon, this.ad, this.aciklama);

  final IconData ikon;
  final String ad;
  final String aciklama;
}

class _ModulKarti extends StatelessWidget {
  const _ModulKarti({
    required this.modul,
    required this.palet,
    required this.vurgu,
  });

  final _Modul modul;
  final MaisonPalet palet;
  final Color vurgu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: palet.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palet.cizgi),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Color.alphaBlend(vurgu.withValues(alpha: 0.10), palet.kart),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(modul.ikon, size: 22, color: vurgu),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  modul.ad,
                  style: maisonGovde(
                    15,
                    renk: palet.yazi,
                    kalinlik: FontWeight.w600,
                    yukseklik: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  modul.aciklama,
                  style: maisonGovde(13, renk: palet.soluk, yukseklik: 1.35),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palet.cizgi),
            ),
            child: Text(
              'Yakında',
              style: maisonGovde(
                11,
                renk: palet.soluk,
                kalinlik: FontWeight.w600,
                yukseklik: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
