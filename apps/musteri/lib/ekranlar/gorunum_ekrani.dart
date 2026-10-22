import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../gorunum.dart';

/// Görünüm: 5 palet, vurgu rengi, koyu mod, yazı boyutu ve dil.
class GorunumEkrani extends StatelessWidget {
  const GorunumEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Gorunum gorunum = GorunumKapsami.of(context);
    return Scaffold(
      backgroundColor: r.zemin,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            MaisonUstSatir(
              sol: MaisonYuvarlakDugme(
                ikon: Icons.arrow_back,
                etiket: dl('Geri', 'Back'),
                onTap: () => Navigator.of(context).maybePop(),
              ),
              baslik: dl('Görünüm', 'Appearance'),
            ),
            const SizedBox(height: 22),
            Text(
              dl(
                'Uygulamanın görünümünü sen seç. Renkler hesabına kaydedilir; telefon değişse de aynı kalır.',
                'Make the app your own. Colours are saved to your account and stay the same on a new phone.',
              ),
              style: maisonGovde(15, renk: r.soluk, yukseklik: 1.5),
            ),
            const SizedBox(height: 26),
            MaisonUstBaslik(dl('TEMA', 'THEME')),
            const SizedBox(height: 14),
            _PaletSecici(gorunum: gorunum),
            const SizedBox(height: 28),
            MaisonUstBaslik(dl('VURGU RENGİ', 'ACCENT COLOUR')),
            const SizedBox(height: 14),
            _VurguSecici(gorunum: gorunum),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              decoration: BoxDecoration(
                color: r.kart,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: r.cizgi),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.dark_mode_outlined, size: 20, color: r.soluk),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(dl('Koyu mod', 'Dark mode'), style: maisonGovde(15, renk: r.yazi, yukseklik: 1.2)),
                  ),
                  MaisonAnahtar(
                    deger: gorunum.koyu,
                    etiket: dl('Koyu mod', 'Dark mode'),
                    onChanged: gorunum.koyuModAyarla,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            MaisonUstBaslik(dl('YAZI BOYUTU', 'TEXT SIZE')),
            const SizedBox(height: 14),
            const MaisonYaziBoyutuSecici(),
            const SizedBox(height: 28),
            MaisonUstBaslik(dl('DİL', 'LANGUAGE')),
            const SizedBox(height: 14),
            const MaisonDilSecici(),
          ],
        ),
      ),
    );
  }
}

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
  const _PaletKarti({required this.palet, required this.secili, required this.onTap});

  final MaisonPalet palet;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Semantics(
      button: true,
      selected: secili,
      label: palet.ad,
      child: Material(
        color: r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: secili ? r.vurgu : r.cizgi, width: secili ? 1.5 : 1.0),
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
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palet.zemin,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palet.cizgi),
                  ),
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
                    renk: r.yazi,
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

class _VurguSecici extends StatelessWidget {
  const _VurguSecici({required this.gorunum});

  final Gorunum gorunum;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final MaisonPalet palet = gorunum.palet;
    return Wrap(
      spacing: 18,
      runSpacing: 14,
      children: <Widget>[
        for (int i = 0; i < palet.vurgular.length; i++)
          Semantics(
            button: true,
            selected: i == gorunum.vurguSirasi,
            label: palet.vurgular[i].ad,
            child: InkWell(
              onTap: () => gorunum.vurguSec(i),
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
                        color: palet.vurgular[i].renk,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == gorunum.vurguSirasi ? r.yazi : r.cizgi,
                          width: i == gorunum.vurguSirasi ? 2.0 : 1.0,
                        ),
                      ),
                      child: i == gorunum.vurguSirasi
                          ? Icon(Icons.check, size: 20, color: palet.vurguUstu)
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      palet.vurgular[i].ad,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: maisonGovde(11, renk: r.soluk, yukseklik: 1.25),
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
