import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';

import '../gorunum.dart';

/// Açılış: kapı kemeri çizilir, makas ve marka belirir, ardından düğmeler gelir.
class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});

  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giris = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _basladi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_basladi) return;
    _basladi = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _giris.value = 1.0;
    } else {
      _giris.forward();
    }
  }

  @override
  void dispose() {
    _giris.dispose();
    super.dispose();
  }

  void _giriseGec(bool kayit) {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MaisonGirisEkrani(oturum: oturum, kayitModu: kayit),
      ),
    );
  }

  void _proBilgisi() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            dl(
              'Maison Makas Pro, işletmeler için ayrı bir uygulamadır.',
              'Maison Makas Pro is a separate app for businesses.',
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Gorunum gorunum = GorunumKapsami.of(context);
    final MaisonPalet palet = gorunum.palet;
    final Color vurgu = gorunum.vurgu;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(palet),
      child: Scaffold(
        backgroundColor: palet.zemin,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _giris,
            builder: (BuildContext context, Widget? _) {
              final double t = _giris.value;
              final double dugmeler = _aralik(t, 0.70, 1.0);
              return Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _DilSecici(
                      secili: MaisonTercih.dil.value,
                      renk: palet.yazi,
                      soluk: palet.soluk,
                      onSec: MaisonTercih.dilSec,
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Vitrin(
                            t: t,
                            palet: palet,
                            vurgu: vurgu,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    IgnorePointer(
                      ignoring: dugmeler < 0.6,
                      child: _Belir(
                        t: dugmeler,
                        kayma: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: () => _giriseGec(true),
                                child: Text(dl('Hemen başla', 'Get started')),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                onPressed: () => _giriseGec(false),
                                child: Text(dl('Hesabım var, giriş yap', 'I have an account, sign in')),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Text(
                                  dl('İşletme sahibi misin?', 'Own a salon?'),
                                  style: maisonGovde(13, renk: palet.soluk),
                                ),
                                InkWell(
                                  onTap: _proBilgisi,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      'Maison Makas Pro',
                                      style: maisonGovde(
                                        13,
                                        renk: vurgu,
                                        kalinlik: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// [t] değerinin [bas]–[son] aralığındaki ilerlemesi (0–1), yumuşatılmış.
double _aralik(double t, double bas, double son, [Curve egri = Curves.easeOutCubic]) {
  if (t <= bas) return 0.0;
  if (t >= son) return 1.0;
  return egri.transform((t - bas) / (son - bas));
}

/// Saydamlık + hafif yukarı kayma ile belirme.
class _Belir extends StatelessWidget {
  const _Belir({required this.t, required this.child, this.kayma = 10.0});

  final double t;
  final double kayma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, (1 - t) * kayma),
        child: child,
      ),
    );
  }
}

/// Kemerli çerçeve, makas, marka adı, slogan ve sayfa noktaları.
class _Vitrin extends StatelessWidget {
  const _Vitrin({
    required this.t,
    required this.palet,
    required this.vurgu,
  });

  final double t;
  final MaisonPalet palet;
  final Color vurgu;

  @override
  Widget build(BuildContext context) {
    final double kilit = _aralik(t, 0.0, 0.18);
    final double kemer = _aralik(t, 0.06, 0.62, Curves.easeInOutCubic);
    final double esik = _aralik(t, 0.48, 0.72);
    final double makas = _aralik(t, 0.32, 0.66);
    final double maison = _aralik(t, 0.42, 0.76);
    final double ad = _aralik(t, 0.50, 0.82);
    final double cubuk = _aralik(t, 0.68, 0.90);
    final double slogan = _aralik(t, 0.60, 0.92);

    final double harfAraligi = 6.0 + 3.6 * (1 - maison);
    final Color pasifNokta =
        Color.alphaBlend(palet.yazi.withValues(alpha: 0.18), palet.zemin);

    return SizedBox(
      width: 334,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 280,
            height: 366,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: CerceveBoyaci(
                      renk: vurgu,
                      kilitTasi: kilit,
                      kemer: kemer,
                      esik: esik,
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Opacity(
                        opacity: makas,
                        child: Transform.scale(
                          scale: 0.9 + 0.1 * makas,
                          child: SizedBox(
                            width: 40,
                            height: 75,
                            child: CustomPaint(
                              painter: MakasBoyaci(renk: vurgu, zemin: palet.zemin),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        opacity: maison,
                        child: Padding(
                          padding: EdgeInsets.only(left: harfAraligi),
                          child: Text(
                            'MAISON',
                            style: maisonGovde(
                              12,
                              renk: vurgu,
                              kalinlik: FontWeight.w500,
                              yukseklik: 1.2,
                              aralik: harfAraligi,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Belir(
                        t: ad,
                        kayma: 8,
                        child: Text(
                          'Makas',
                          style: maisonBaslik(
                            68,
                            renk: palet.yazi,
                            yukseklik: 0.9,
                            aralik: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: 36 * cubuk,
                        height: 1,
                        color: vurgu,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _Belir(
            t: slogan,
            kayma: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  dl('Usta ellere, tek dokunuşla.', 'Into master hands, with a single tap.'),
                  textAlign: TextAlign.center,
                  style: maisonBaslik(
                    26,
                    renk: palet.yazi,
                    bicim: FontStyle.italic,
                    yukseklik: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 290,
                  child: Text(
                    dl(
                      'Berberini ve kuaförünü bul, saniyeler içinde randevunu al.',
                      'Find your barber or hairdresser and book in seconds.',
                    ),
                    textAlign: TextAlign.center,
                    style: maisonGovde(15, renk: palet.soluk, yukseklik: 1.5),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Nokta(genislik: 20, renk: vurgu),
                    const SizedBox(width: 6),
                    _Nokta(genislik: 6, renk: pasifNokta),
                    const SizedBox(width: 6),
                    _Nokta(genislik: 6, renk: pasifNokta),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Nokta extends StatelessWidget {
  const _Nokta({required this.genislik, required this.renk});

  final double genislik;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: genislik,
      height: 6,
      decoration: BoxDecoration(
        color: renk,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// Sağ üstteki TR · EN seçici.
class _DilSecici extends StatelessWidget {
  const _DilSecici({
    required this.secili,
    required this.renk,
    required this.soluk,
    required this.onSec,
  });

  final MaisonDil secili;
  final Color renk;
  final Color soluk;
  final ValueChanged<MaisonDil> onSec;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        for (final MaisonDil dil in MaisonDil.values)
          Semantics(
            button: true,
            selected: dil == secili,
            label: dil.ad,
            child: InkWell(
              onTap: () => onSec(dil),
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    dil.kod,
                    style: maisonGovde(
                      12,
                      renk: dil == secili ? renk : soluk,
                      kalinlik: dil == secili ? FontWeight.w600 : FontWeight.w500,
                      yukseklik: 1.2,
                      aralik: 1.44,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
