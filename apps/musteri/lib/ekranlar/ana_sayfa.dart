import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../veri.dart';
import 'salon_ekrani.dart';

class _AnaVeri {
  const _AnaVeri({required this.yaklasan, required this.salonlar});

  final List<RandevuOzet> yaklasan;
  final List<SalonOzet> salonlar;
}

/// Ana sayfa: selam, arama, yaklaşan randevu, favori ustalar ve salonlar.
class AnaSayfa extends StatefulWidget {
  const AnaSayfa({
    super.key,
    required this.menuAc,
    required this.kesfeteGit,
    required this.randevularaGit,
  });

  final VoidCallback menuAc;
  final VoidCallback kesfeteGit;
  final VoidCallback randevularaGit;

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  Future<_AnaVeri>? _gelecek;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gelecek ??= _yukle();
  }

  Future<_AnaVeri> _yukle() async {
    final Veri veri = Veri.of(context);
    final List<RandevuOzet> yaklasan = await veri.randevularim();
    final List<SalonOzet> salonlar = await veri.kesfet();
    return _AnaVeri(yaklasan: yaklasan, salonlar: salonlar);
  }

  Future<void> _yenile() async {
    final Future<_AnaVeri> f = _yukle();
    setState(() => _gelecek = f);
    try {
      await f;
    } catch (_) {
      // Hata kartta gösterilir.
    }
  }

  void _bildirimYok() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Yeni bildirimin yok.')));
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final MaisonOturum oturum = OturumKapsami.of(context);
    final String ad = oturum.ilkAd;
    return RefreshIndicator(
      color: r.vurgu,
      backgroundColor: r.kart,
      onRefresh: _yenile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          MaisonUstSatir(
            sol: MaisonYuvarlakDugme(ikon: Icons.menu, etiket: 'Menüyü aç', onTap: widget.menuAc),
            baslik: 'Maison Makas',
            sag: MaisonYuvarlakDugme(
              ikon: Icons.notifications_none,
              etiket: 'Bildirimler',
              onTap: _bildirimYok,
            ),
          ),
          const SizedBox(height: 20),
          MaisonUstBaslik(maisonSelamlama(DateTime.now())),
          const SizedBox(height: 4),
          Text(
            ad.isEmpty ? 'Merhaba' : 'Merhaba, $ad',
            style: maisonBaslik(38, renk: r.yazi, yukseklik: 1.1),
          ),
          const SizedBox(height: 18),
          _AramaKutusu(onTap: widget.kesfeteGit),
          const SizedBox(height: 18),
          FutureBuilder<_AnaVeri>(
            future: _gelecek,
            builder: (BuildContext context, AsyncSnapshot<_AnaVeri> durum) {
              if (durum.hasError) {
                return MaisonHataKutusu(maisonHataMetni(durum.error!), tekrar: _yenile);
              }
              final _AnaVeri? veri = durum.data;
              if (veri == null) {
                return const MaisonYukleniyor();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _YaklasanKart(
                    randevu: veri.yaklasan.isEmpty ? null : veri.yaklasan.first,
                    randevularaGit: widget.randevularaGit,
                    kesfeteGit: widget.kesfeteGit,
                  ),
                  const SizedBox(height: 26),
                  const MaisonBolumBasligi('Favori ustalar'),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      _EkleDairesi(onTap: widget.kesfeteGit),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Gittiğin salonlardaki ustaları favorine ekle; bir dokunuşla aynı ustadan randevu al.',
                          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  MaisonBolumBasligi(
                    'Salonlar',
                    baglanti: veri.salonlar.isEmpty ? null : 'Tümü',
                    onBaglanti: widget.kesfeteGit,
                  ),
                  const SizedBox(height: 10),
                  if (veri.salonlar.isEmpty)
                    Text(
                      'Salonlar Makas Pro\'dan katıldıkça burada görünecek.',
                      style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
                    )
                  else
                    SizedBox(
                      height: 212,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: veri.salonlar.length,
                        separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 14),
                        itemBuilder: (BuildContext context, int i) {
                          return _SalonKarti(salon: veri.salonlar[i]);
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AramaKutusu extends StatelessWidget {
  const _AramaKutusu({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Semantics(
      button: true,
      label: 'Ara',
      child: Material(
        color: r.girdi,
        shape: StadiumBorder(side: BorderSide(color: r.cizgi)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 18),
                Icon(Icons.search, size: 20, color: r.soluk),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Salon, semt ya da şehir ara',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: maisonGovde(15, renk: r.soluk, yukseklik: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YaklasanKart extends StatelessWidget {
  const _YaklasanKart({
    required this.randevu,
    required this.randevularaGit,
    required this.kesfeteGit,
  });

  final RandevuOzet? randevu;
  final VoidCallback randevularaGit;
  final VoidCallback kesfeteGit;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final RandevuOzet? rv = randevu;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: rv == null ? r.cizgi : r.vurguCizgi),
      ),
      child: rv == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                MaisonUstBaslik('RANDEVU', renk: r.vurgu),
                const SizedBox(height: 10),
                Text('Yaklaşan randevun yok', style: maisonBaslik(24, renk: r.yazi)),
                const SizedBox(height: 6),
                Text(
                  'Bir salon seç, ustanı ve saatini belirle.',
                  style: maisonGovde(14, renk: r.soluk, yukseklik: 1.45),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: FilledButton(onPressed: kesfeteGit, child: const Text('Salon bul')),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: MaisonUstBaslik('YAKLAŞAN RANDEVU', renk: r.vurgu)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: r.vurguYumusak,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        maisonKalan(rv.baslangic),
                        style: maisonGovde(12, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: r.cizgi),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            maisonAyBuyuk(rv.baslangic),
                            style: maisonGovde(10, renk: r.soluk, yukseklik: 1.2, aralik: 1.4),
                          ),
                          Text(
                            '${rv.baslangic.day}',
                            style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${maisonGun(rv.baslangic)} · ${maisonSaat(rv.baslangic)}',
                            style: maisonGovde(16, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${rv.hizmetler ?? 'Randevu'} · ${rv.ustaAd}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.35),
                          ),
                          Text(
                            rv.salonIlce == null ? rv.salonAd : '${rv.salonAd}, ${rv.salonIlce}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: randevularaGit,
                    child: const Text('Randevularım'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _EkleDairesi extends StatelessWidget {
  const _EkleDairesi({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Semantics(
      button: true,
      label: 'Favori usta ekle',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: r.cizgi),
              ),
              child: Icon(Icons.add, color: r.soluk, size: 22),
            ),
            const SizedBox(height: 8),
            Text('Ekle', style: maisonGovde(13, renk: r.soluk, yukseklik: 1.2)),
          ],
        ),
      ),
    );
  }
}

class _SalonKarti extends StatelessWidget {
  const _SalonKarti({required this.salon});

  final SalonOzet salon;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return SizedBox(
      width: 240,
      child: Material(
        color: r.kart,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => SalonEkrani(salon: salon),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  const MaisonKapak(yukseklik: 120),
                  if (salon.dogrulandi)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: _Rozet(metin: 'Doğrulanmış salon', renk: r.zemin.withValues(alpha: 0.8)),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      salon.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonBaslik(22, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(Icons.star, size: 14, color: r.vurgu),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            salon.ozet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: maisonGovde(13, renk: r.soluk, yukseklik: 1.2),
                          ),
                        ),
                      ],
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

class _Rozet extends StatelessWidget {
  const _Rozet({required this.metin, required this.renk});

  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
      child: Text(
        metin,
        style: maisonGovde(12, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.2),
      ),
    );
  }
}
