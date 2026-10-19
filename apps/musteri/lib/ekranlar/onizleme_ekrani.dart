import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';

import '../dil.dart';
import '../gorunum.dart';

/// İlk derlemenin karşılama sayfası: görünüm seçimi canlı çalışır.
class OnizlemeEkrani extends StatelessWidget {
  const OnizlemeEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final Gorunum gorunum = GorunumKapsami.of(context);
    final MaisonPalet palet = gorunum.palet;
    final Color vurgu = gorunum.vurgu;
    final Metinler metin = gorunum.metin;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(palet),
      child: Scaffold(
        backgroundColor: palet.zemin,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: metin.geri,
                    color: palet.yazi,
                  ),
                  const Spacer(),
                  MaisonAmblem(renk: vurgu, zemin: palet.zemin, genislik: 22),
                  const SizedBox(width: 14),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    Text(
                      'MAISON MAKAS',
                      style: maisonGovde(
                        11,
                        renk: vurgu,
                        kalinlik: FontWeight.w600,
                        aralik: 2.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      metin.hosGeldin,
                      style: maisonBaslik(40, renk: palet.yazi, yukseklik: 1.05),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      metin.ilkDerleme,
                      style: maisonGovde(15, renk: palet.soluk, yukseklik: 1.55),
                    ),
                    const SizedBox(height: 32),
                    _Etiket(metin.temaBasligi, renk: palet.soluk),
                    const SizedBox(height: 14),
                    _PaletSecici(gorunum: gorunum),
                    const SizedBox(height: 26),
                    _Etiket(metin.vurguBasligi, renk: palet.soluk),
                    const SizedBox(height: 14),
                    _VurguSecici(gorunum: gorunum),
                    const SizedBox(height: 32),
                    _SiradakiKart(palet: palet, vurgu: vurgu, metin: metin),
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

class _Etiket extends StatelessWidget {
  const _Etiket(this.metin, {required this.renk});

  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Text(
      metin,
      style: maisonGovde(11, renk: renk, kalinlik: FontWeight.w600, aralik: 2.2),
    );
  }
}

/// Beş palet; dokununca tüm uygulama o görünüme geçer.
class _PaletSecici extends StatelessWidget {
  const _PaletSecici({required this.gorunum});

  final Gorunum gorunum;

  @override
  Widget build(BuildContext context) {
    final MaisonPalet secili = gorunum.palet;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints sinir) {
        final double genislik = (sinir.maxWidth - 20) / 3;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final MaisonPalet p in MaisonPalet.tumu)
              SizedBox(
                width: genislik,
                child: _PaletKarti(
                  palet: p,
                  secili: identical(p, secili),
                  cerceve: secili,
                  vurgu: gorunum.vurgu,
                  onTap: () => gorunum.paletSec(p),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PaletKarti extends StatelessWidget {
  const _PaletKarti({
    required this.palet,
    required this.secili,
    required this.cerceve,
    required this.vurgu,
    required this.onTap,
  });

  /// Kartın gösterdiği palet.
  final MaisonPalet palet;
  final bool secili;

  /// Şu an uygulanan palet (kartın kendi zemini ve çizgisi için).
  final MaisonPalet cerceve;
  final Color vurgu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: secili,
      label: palet.ad,
      child: Material(
        color: cerceve.kart,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: secili ? vurgu : cerceve.cizgi,
            width: secili ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: palet.zemin,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palet.cizgi),
                  ),
                  alignment: Alignment.center,
                  child: MaisonAmblem(
                    renk: palet.vurgu,
                    zemin: palet.zemin,
                    genislik: 26,
                    etiket: palet.ad,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  palet.ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: maisonGovde(
                    13,
                    renk: cerceve.yazi,
                    kalinlik: secili ? FontWeight.w600 : FontWeight.w500,
                    yukseklik: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seçili paletin dört vurgu rengi.
class _VurguSecici extends StatelessWidget {
  const _VurguSecici({required this.gorunum});

  final Gorunum gorunum;

  @override
  Widget build(BuildContext context) {
    final MaisonPalet palet = gorunum.palet;
    return Wrap(
      spacing: 18,
      runSpacing: 14,
      children: <Widget>[
        for (final MaisonVurgu v in palet.vurgular)
          Semantics(
            button: true,
            selected: v.renk == gorunum.vurgu,
            label: v.ad,
            child: InkWell(
              onTap: () => gorunum.vurguSec(v.renk),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: v.renk,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: v.renk == gorunum.vurgu
                              ? palet.yazi
                              : palet.cizgi,
                          width: v.renk == gorunum.vurgu ? 2.0 : 1.0,
                        ),
                      ),
                      child: v.renk == gorunum.vurgu
                          ? Icon(Icons.check, size: 20, color: palet.vurguUstu)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      v.ad,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: maisonGovde(11, renk: palet.soluk, yukseklik: 1.25),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SiradakiKart extends StatelessWidget {
  const _SiradakiKart({
    required this.palet,
    required this.vurgu,
    required this.metin,
  });

  final MaisonPalet palet;
  final Color vurgu;
  final Metinler metin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: palet.kart,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palet.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metin.siradakiBaslik,
            style: maisonBaslik(24, renk: palet.yazi),
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < metin.siradakiler.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: vurgu),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: maisonGovde(
                        12,
                        renk: vurgu,
                        kalinlik: FontWeight.w600,
                        yukseklik: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      metin.siradakiler[i],
                      style: maisonGovde(15, renk: palet.yazi, yukseklik: 1.35),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
