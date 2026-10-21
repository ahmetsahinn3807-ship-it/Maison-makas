import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../gorunum.dart';

/// Menüden gidilebilecek yerler.
enum MenuHedefi {
  profil,
  kesfet,
  randevuYaklasan,
  randevuGecmis,
  beklemeListesi,
  favoriler,
  cuzdan,
  mesajlar,
  gorunum,
  ayarlar,
}

/// Soldan açılan ana menü: kapak, profil, başlıklar ve alt sekmeler, koyu mod.
class MusteriMenu extends StatefulWidget {
  const MusteriMenu({super.key, required this.onSec});

  final ValueChanged<MenuHedefi> onSec;

  @override
  State<MusteriMenu> createState() => _MusteriMenuState();
}

class _MusteriMenuState extends State<MusteriMenu> {
  bool _randevularAcik = true;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final MaisonOturum oturum = OturumKapsami.of(context);
    final Gorunum gorunum = GorunumKapsami.of(context);
    final double ust = MediaQuery.paddingOf(context).top;
    final double kapakYuksekligi = 96 + ust;

    return Drawer(
      width: 306,
      backgroundColor: r.menu,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        side: BorderSide(color: r.cizgi),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                SizedBox(
                  height: kapakYuksekligi + 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: MaisonKapak(
                          yukseklik: kapakYuksekligi,
                          url: oturum.kapakUrl,
                          odak: oturum.kapakOdak,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: ust + 8,
                        child: MaisonYuvarlakDugme(
                          ikon: Icons.close,
                          etiket: 'Menüyü kapat',
                          zemin: r.zemin.withValues(alpha: 0.6),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        top: kapakYuksekligi - 34,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            MaisonAvatar(
                              basHarfler: oturum.basHarfler,
                              halkaRengi: r.menu,
                              fotoUrl: oturum.avatarUrl,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      oturum.adSoyad.isEmpty ? 'Hoş geldin' : oturum.adSoyad,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: maisonGovde(17, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.25),
                                    ),
                                    InkWell(
                                      onTap: () => widget.onSec(MenuHedefi.profil),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          'Profili düzenle',
                                          style: maisonGovde(13, renk: r.vurgu, kalinlik: FontWeight.w500, yukseklik: 1.2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: <Widget>[
                      _Cip(
                        ikon: Icons.calendar_today_outlined,
                        etiket: 'Yaklaşan',
                        onTap: () => widget.onSec(MenuHedefi.randevuYaklasan),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Divider(color: r.cizgi, height: 1, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: <Widget>[
                      _MenuSatiri(
                        ikon: Icons.explore_outlined,
                        etiket: 'Keşfet',
                        onTap: () => widget.onSec(MenuHedefi.kesfet),
                      ),
                      _MenuSatiri(
                        ikon: Icons.calendar_month_outlined,
                        etiket: 'Randevularım',
                        vurgulu: true,
                        sag: Icon(
                          _randevularAcik ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: r.soluk,
                        ),
                        onTap: () => setState(() => _randevularAcik = !_randevularAcik),
                      ),
                      if (_randevularAcik)
                        Padding(
                          padding: const EdgeInsets.only(left: 44, bottom: 4),
                          child: Column(
                            children: <Widget>[
                              _AltSatir(
                                etiket: 'Yaklaşan',
                                onTap: () => widget.onSec(MenuHedefi.randevuYaklasan),
                              ),
                              _AltSatir(
                                etiket: 'Geçmiş',
                                onTap: () => widget.onSec(MenuHedefi.randevuGecmis),
                              ),
                              _AltSatir(
                                etiket: 'Bekleme listesi',
                                onTap: () => widget.onSec(MenuHedefi.beklemeListesi),
                              ),
                            ],
                          ),
                        ),
                      _MenuSatiri(
                        ikon: Icons.favorite_border,
                        etiket: 'Favorilerim',
                        onTap: () => widget.onSec(MenuHedefi.favoriler),
                      ),
                      _MenuSatiri(
                        ikon: Icons.person_outline,
                        etiket: 'Profilim',
                        onTap: () => widget.onSec(MenuHedefi.profil),
                      ),
                      _MenuSatiri(
                        ikon: Icons.account_balance_wallet_outlined,
                        etiket: 'Cüzdan ve sadakat',
                        onTap: () => widget.onSec(MenuHedefi.cuzdan),
                      ),
                      _MenuSatiri(
                        ikon: Icons.chat_bubble_outline,
                        etiket: 'Mesajlar',
                        onTap: () => widget.onSec(MenuHedefi.mesajlar),
                      ),
                      _MenuSatiri(
                        ikon: Icons.palette_outlined,
                        etiket: 'Görünüm',
                        onTap: () => widget.onSec(MenuHedefi.gorunum),
                      ),
                      _MenuSatiri(
                        ikon: Icons.tune,
                        etiket: 'Ayarlar ve destek',
                        onTap: () => widget.onSec(MenuHedefi.ayarlar),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: r.cizgi))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 14, 10),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.dark_mode_outlined, size: 20, color: r.soluk),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('Koyu mod', style: maisonGovde(15, renk: r.yazi, yukseklik: 1.2)),
                    ),
                    MaisonAnahtar(
                      deger: gorunum.koyu,
                      etiket: 'Koyu mod',
                      onChanged: gorunum.koyuModAyarla,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cip extends StatelessWidget {
  const _Cip({required this.ikon, required this.etiket, required this.onTap});

  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Material(
      color: r.vurguYumusak,
      shape: StadiumBorder(side: BorderSide(color: r.vurguCizgi)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(ikon, size: 15, color: r.vurgu),
                const SizedBox(width: 7),
                Text(etiket, style: maisonGovde(13, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuSatiri extends StatelessWidget {
  const _MenuSatiri({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.vurgulu = false,
    this.sag,
  });

  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;
  final bool vurgulu;
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              Icon(ikon, size: 20, color: vurgulu ? r.vurgu : r.soluk),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  etiket,
                  style: maisonGovde(
                    15,
                    renk: r.yazi,
                    kalinlik: vurgulu ? FontWeight.w600 : FontWeight.w400,
                    yukseklik: 1.2,
                  ),
                ),
              ),
              sag ?? Icon(Icons.chevron_right, size: 18, color: r.soluk.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AltSatir extends StatelessWidget {
  const _AltSatir({required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(etiket, style: maisonGovde(14, renk: r.soluk, yukseklik: 1.2)),
      ),
    );
  }
}
