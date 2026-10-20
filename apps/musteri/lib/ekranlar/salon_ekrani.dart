import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../veri.dart';

/// Salonun vitrin sayfasının ilk hali: kapak, ad, puan ve hizmet menüsü.
/// Fotoğraflar 19. adımda, randevu alma 21. adımda gelir.
class SalonEkrani extends StatefulWidget {
  const SalonEkrani({super.key, required this.salon});

  final SalonOzet salon;

  @override
  State<SalonEkrani> createState() => _SalonEkraniState();
}

class _SalonEkraniState extends State<SalonEkrani> {
  Future<List<HizmetOzet>>? _gelecek;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gelecek ??= Veri.of(context).hizmetler(widget.salon.id);
  }

  void _tekrarDene() {
    setState(() => _gelecek = Veri.of(context).hizmetler(widget.salon.id));
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final double ust = MediaQuery.paddingOf(context).top;
    final SalonOzet s = widget.salon;
    return Scaffold(
      backgroundColor: r.zemin,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          SizedBox(
            height: 200 + ust + 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: MaisonKapak(yukseklik: 200 + ust),
                ),
                Positioned(
                  left: 16,
                  top: ust + 8,
                  child: MaisonYuvarlakDugme(
                    ikon: Icons.arrow_back,
                    etiket: 'Geri',
                    zemin: r.zemin.withValues(alpha: 0.6),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 200 + ust - 44,
                  child: Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: r.zemin,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: r.kart,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(color: r.vurgu, width: 1.5),
                      ),
                      child: MaisonAmblem(renk: r.vurgu, zemin: r.kart, genislik: 30, etiket: s.ad),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        s.ad,
                        style: maisonBaslik(36, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.05),
                      ),
                    ),
                    if (s.dogrulandi) Icon(Icons.verified_outlined, color: r.vurgu),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(Icons.star, size: 16, color: r.vurgu),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.yorumAdet > 0 ? '${s.ozet} · ${s.yorumAdet} yorum' : s.ozet,
                        style: maisonGovde(14, renk: r.soluk, yukseklik: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: r.vurguYumusak,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: r.vurguCizgi),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(Icons.event_available_outlined, color: r.vurgu, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Online randevu çok yakında: salon takvimi açıldığında buradan usta ve saat seçebileceksin.',
                          style: maisonGovde(14, renk: r.yazi, yukseklik: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const MaisonBolumBasligi('Hizmetler'),
                const SizedBox(height: 8),
                FutureBuilder<List<HizmetOzet>>(
                  future: _gelecek,
                  builder: (BuildContext context, AsyncSnapshot<List<HizmetOzet>> durum) {
                    if (durum.hasError) {
                      return MaisonHataKutusu(maisonHataMetni(durum.error!), tekrar: _tekrarDene);
                    }
                    final List<HizmetOzet>? liste = durum.data;
                    if (liste == null) {
                      return const MaisonYukleniyor();
                    }
                    if (liste.isEmpty) {
                      return Text(
                        'Salon hizmet menüsünü henüz eklemedi.',
                        style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
                      );
                    }
                    return Column(
                      children: <Widget>[
                        for (final HizmetOzet h in liste)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: r.cizgi)),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        h.ad,
                                        style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        maisonSure(h.sureDk),
                                        style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  maisonPara(h.fiyat, 'TRY'),
                                  style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
