import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';

/// Giriş yapmamış işletme sahibine Makas Pro'yu tanıtır.
class ProAcilis extends StatelessWidget {
  const ProAcilis({super.key});

  static const List<_Modul> _moduller = <_Modul>[
    _Modul(Icons.today_outlined, 'Bugün', 'Günün randevuları tek bakışta'),
    _Modul(Icons.calendar_month_outlined, 'Takvim', 'Haftalık görünüm, boş saatler'),
    _Modul(Icons.groups_outlined, 'Ekip', 'Ustalar, çalışma saatleri, izinler'),
    _Modul(Icons.content_cut, 'Hizmetler', 'Süre ve fiyat listesi'),
    _Modul(Icons.storefront_outlined, 'Vitrin', 'Profil, duvar fotoğrafı, galeri'),
    _Modul(Icons.insights_outlined, 'Kazanç', 'Günlük ve aylık özet'),
  ];

  void _giris(BuildContext context, bool kayit) {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MaisonGirisEkrani(
          oturum: oturum,
          kayitModu: kayit,
          ustBaslik: 'MAKAS PRO',
          girisAciklama: 'Salonunun takvimini, ekibini ve kasasını tek yerden yönet.',
          kayitAciklama: 'Hesabını oluştur, ardından salonunu birkaç adımda kur.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonPalet.ivoire),
      child: Scaffold(
        backgroundColor: r.zemin,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        MaisonAmblem(renk: r.vurgu, zemin: r.zemin, genislik: 46),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              MaisonUstBaslik('MAISON MAKAS', renk: r.vurgu),
                              Text(
                                'Pro',
                                style: maisonBaslik(56, renk: r.yazi, yukseklik: 1.0),
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
                        renk: r.yazi,
                        bicim: FontStyle.italic,
                        yukseklik: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Salonunu kur, hizmetlerini ve ustalarını ekle; müşterilerin Maison Makas\'tan randevu alsın.',
                      style: maisonGovde(15, renk: r.soluk, yukseklik: 1.55),
                    ),
                    const SizedBox(height: 24),
                    const MaisonUstBaslik('MODÜLLER'),
                    const SizedBox(height: 12),
                    for (final _Modul modul in _moduller)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ModulKarti(modul: modul),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: () => _giris(context, false),
                        child: const Text('Giriş yap'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => _giris(context, true),
                        child: const Text('İşletme hesabı oluştur'),
                      ),
                    ),
                  ],
                ),
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
  const _ModulKarti({required this.modul});

  final _Modul modul;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: r.cizgi),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: r.vurguYumusak,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(modul.ikon, size: 22, color: r.vurgu),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  modul.ad,
                  style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                ),
                const SizedBox(height: 2),
                Text(
                  modul.aciklama,
                  style: maisonGovde(13, renk: r.soluk, yukseklik: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
