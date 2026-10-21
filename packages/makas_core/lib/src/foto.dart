import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'renkler.dart';
import 'tema.dart';
import 'vitrin_ayari.dart';

/// Odak noktasını (0–1 aralığında x, y) kırpma hizasına çevirir.
Alignment maisonOdakHizasi(Offset odak) {
  final double x = odak.dx.clamp(0.0, 1.0).toDouble();
  final double y = odak.dy.clamp(0.0, 1.0).toDouble();
  return Alignment(x * 2 - 1, y * 2 - 1);
}

/// Ağdaki bir fotoğraf: alanı doldurur, odak noktasına göre kırpılır, vitrin filtresi uygulanır.
/// Adres yoksa ya da yüklenemezse [yedek] (yoksa sıcak bir zemin) görünür; yüklenince yumuşakça belirir.
class MaisonFoto extends StatelessWidget {
  const MaisonFoto({
    super.key,
    required this.url,
    this.odak = const Offset(0.5, 0.5),
    this.filtre = VitrinFiltresi.dogal,
    this.yedek,
    this.zemin,
    this.etiket,
    this.sigdir = false,
  });

  final String? url;
  final Offset odak;
  final VitrinFiltresi filtre;
  final Widget? yedek;
  final Color? zemin;

  /// Ekran okuyucu için açıklama; yoksa fotoğraf süs sayılır.
  final String? etiket;

  /// true: kırpmadan sığdırır (tam ekran görüntüleyici).
  final bool sigdir;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Color arka = zemin ?? r.kapak;
    final Widget bos = yedek ?? ColoredBox(color: arka);
    final String? adres = url;
    if (adres == null || adres.isEmpty) {
      return bos;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints kisit) {
        final double oran = MediaQuery.devicePixelRatioOf(context);
        final double genislik = kisit.maxWidth.isFinite ? kisit.maxWidth : 0;
        final double yukseklik = kisit.maxHeight.isFinite ? kisit.maxHeight : 0;
        final double uzun = math.max(genislik, yukseklik);
        final int? cozunurluk = uzun > 0 ? math.min((uzun * oran * 1.5).round(), 2048) : null;
        Widget resim = Image.network(
          adres,
          fit: sigdir ? BoxFit.contain : BoxFit.cover,
          alignment: sigdir ? Alignment.center : maisonOdakHizasi(odak),
          width: genislik > 0 ? genislik : null,
          height: yukseklik > 0 ? yukseklik : null,
          cacheWidth: sigdir ? null : cozunurluk,
          semanticLabel: etiket,
          excludeFromSemantics: etiket == null,
          gaplessPlayback: true,
          frameBuilder: (BuildContext context, Widget child, int? kare, bool hemenGeldi) {
            if (hemenGeldi) {
              return child;
            }
            return AnimatedOpacity(
              opacity: kare == null ? 0 : 1,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (BuildContext context, Object hata, StackTrace? iz) => bos,
        );
        final ColorFilter? suzgec = filtre.suzgec;
        if (suzgec != null) {
          resim = ColorFiltered(colorFilter: suzgec, child: resim);
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (!sigdir) ColoredBox(color: arka),
            resim,
          ],
        );
      },
    );
  }
}

/// Bir fotoğraf listesini tam ekranda kaydırarak gösterir; iki parmakla büyütülür.
class MaisonFotoGosterici extends StatefulWidget {
  const MaisonFotoGosterici({
    super.key,
    required this.adresler,
    this.aciklamalar = const <String?>[],
    this.ilk = 0,
    this.filtre = VitrinFiltresi.dogal,
  });

  final List<String> adresler;
  final List<String?> aciklamalar;
  final int ilk;
  final VitrinFiltresi filtre;

  @override
  State<MaisonFotoGosterici> createState() => _MaisonFotoGostericiState();
}

class _MaisonFotoGostericiState extends State<MaisonFotoGosterici> {
  late final PageController _sayfa = PageController(initialPage: widget.ilk);
  late int _simdiki = widget.ilk;

  @override
  void dispose() {
    _sayfa.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? aciklama =
        _simdiki < widget.aciklamalar.length ? widget.aciklamalar[_simdiki] : null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _sayfa,
            itemCount: widget.adresler.length,
            onPageChanged: (int i) => setState(() => _simdiki = i),
            itemBuilder: (BuildContext context, int i) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: MaisonFoto(
                    url: widget.adresler[i],
                    filtre: widget.filtre,
                    zemin: Colors.black,
                    sigdir: true,
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  if (widget.adresler.length > 1)
                    Text(
                      '${_simdiki + 1} / ${widget.adresler.length}',
                      style: maisonGovde(14, renk: Colors.white, kalinlik: FontWeight.w500),
                    ),
                ],
              ),
            ),
          ),
          if (aciklama != null && aciklama.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    aciklama,
                    textAlign: TextAlign.center,
                    style: maisonGovde(15, renk: Colors.white, yukseklik: 1.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
