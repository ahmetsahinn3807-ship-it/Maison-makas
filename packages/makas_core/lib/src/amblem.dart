import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Amblemin çizim biçimi: uygulama ikonu için kalın, logo ve ekranlar için ince.
enum AmblemBicimi { kalin, ince }

// Makas bıçakları (200 × 280 birimlik çizim alanında).
const List<Offset> _kalinSolBicak = <Offset>[
  Offset(84.81, 202.91),
  Offset(111.81, 153.14),
  Offset(141.17, 73.07),
  Offset(99.11, 147.26),
  Offset(78.64, 200.05),
];
const List<Offset> _kalinSagBicak = <Offset>[
  Offset(121.37, 200.05),
  Offset(100.89, 147.26),
  Offset(58.83, 73.07),
  Offset(88.19, 153.14),
  Offset(115.20, 202.91),
];
const List<Offset> _inceSolBicak = <Offset>[
  Offset(83.26, 202.19),
  Offset(108.91, 151.80),
  Offset(141.17, 73.07),
  Offset(102.01, 148.60),
  Offset(80.18, 200.77),
];
const List<Offset> _inceSagBicak = <Offset>[
  Offset(119.82, 200.77),
  Offset(97.99, 148.60),
  Offset(58.83, 73.07),
  Offset(91.09, 151.80),
  Offset(116.74, 202.19),
];
const Offset _pim = Offset(100, 162);
const Offset _solHalka = Offset(75, 216);
const Offset _sagHalka = Offset(125, 216);

/// Makası 200 × 280 birimlik çizim alanına çizer.
void maisonMakasCiz(
  Canvas canvas, {
  required Color renk,
  required Color zemin,
  required bool kalin,
}) {
  final Paint halka = Paint()
    ..color = renk
    ..style = PaintingStyle.stroke
    ..strokeWidth = kalin ? 8.5 : 3.2;
  canvas.drawCircle(_solHalka, 16.0, halka);
  canvas.drawCircle(_sagHalka, 16.0, halka);

  final Paint dolgu = Paint()..color = renk;
  canvas.drawPath(Path()..addPolygon(kalin ? _kalinSolBicak : _inceSolBicak, true), dolgu);
  canvas.drawPath(Path()..addPolygon(kalin ? _kalinSagBicak : _inceSagBicak, true), dolgu);

  final double pimYaricap = kalin ? 7.0 : 4.2;
  canvas.drawCircle(_pim, pimYaricap, Paint()..color = zemin);
  canvas.drawCircle(
    _pim,
    pimYaricap,
    Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalin ? 3.2 : 1.6,
  );
}

/// Kapı kemeri + makas amblemi.
class MaisonAmblem extends StatelessWidget {
  const MaisonAmblem({
    super.key,
    required this.renk,
    required this.zemin,
    this.bicim = AmblemBicimi.ince,
    this.genislik = 100.0,
    this.etiket = 'Maison Makas',
  });

  /// Çizgi ve dolgu rengi.
  final Color renk;

  /// Pimin iç rengi (genelde ekran zemini).
  final Color zemin;
  final AmblemBicimi bicim;

  /// Genişlik; yükseklik bunun 1,4 katıdır.
  final double genislik;

  /// Ekran okuyucu etiketi.
  final String etiket;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiket,
      image: true,
      child: SizedBox(
        width: genislik,
        height: genislik * 1.4,
        child: CustomPaint(
          painter: AmblemBoyaci(renk: renk, zemin: zemin, bicim: bicim),
        ),
      ),
    );
  }
}

/// [MaisonAmblem] çizimi.
class AmblemBoyaci extends CustomPainter {
  const AmblemBoyaci({
    required this.renk,
    required this.zemin,
    this.bicim = AmblemBicimi.ince,
  });

  final Color renk;
  final Color zemin;
  final AmblemBicimi bicim;

  @override
  void paint(Canvas canvas, Size size) {
    final bool kalin = bicim == AmblemBicimi.kalin;
    canvas.save();
    canvas.scale(size.width / 200, size.height / 280);

    final Paint cizgi = Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalin ? 9.0 : 3.0;

    // Kemer
    canvas.drawPath(_kemer(const Offset(100, 104), 76, 262), cizgi);
    if (!kalin) {
      canvas.drawPath(
        _kemer(const Offset(100, 104), 64, 262),
        Paint()
          ..color = renk.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Eşik
    canvas.drawLine(
      Offset(kalin ? 8.0 : 12.0, 262),
      Offset(kalin ? 192.0 : 188.0, 262),
      cizgi,
    );

    // Kilit taşı
    final Path kilit = kalin
        ? (Path()
          ..moveTo(100, 12)
          ..lineTo(116, 28)
          ..lineTo(100, 44)
          ..lineTo(84, 28)
          ..close())
        : (Path()
          ..moveTo(100, 24)
          ..lineTo(110, 34)
          ..lineTo(100, 44)
          ..lineTo(90, 34)
          ..close());
    canvas.drawPath(kilit, Paint()..color = renk);

    maisonMakasCiz(canvas, renk: renk, zemin: zemin, kalin: kalin);
    canvas.restore();
  }

  static Path _kemer(Offset merkez, double yaricap, double tabanY) {
    return Path()
      ..moveTo(merkez.dx - yaricap, tabanY)
      ..lineTo(merkez.dx - yaricap, merkez.dy)
      ..arcTo(Rect.fromCircle(center: merkez, radius: yaricap), math.pi, math.pi, false)
      ..lineTo(merkez.dx + yaricap, tabanY);
  }

  @override
  bool shouldRepaint(covariant AmblemBoyaci eski) {
    return eski.renk != renk || eski.zemin != zemin || eski.bicim != bicim;
  }
}

/// Yalnızca makas; logodaki gibi sıkı kırpılmış (genişlik : yükseklik = 92 : 172).
class MakasBoyaci extends CustomPainter {
  const MakasBoyaci({required this.renk, required this.zemin});

  final Color renk;
  final Color zemin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 92, size.height / 172);
    canvas.translate(-54, -68);
    maisonMakasCiz(canvas, renk: renk, zemin: zemin, kalin: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MakasBoyaci eski) {
    return eski.renk != renk || eski.zemin != zemin;
  }
}

/// Açılış ekranındaki çerçeve: çift kemer, kilit taşı ve eşik (260 × 340 birim).
///
/// Üç ilerleme değeri (0–1) giriş animasyonunu yönetir; hepsi 1 iken çizim tamdır.
class CerceveBoyaci extends CustomPainter {
  const CerceveBoyaci({
    required this.renk,
    this.kilitTasi = 1.0,
    this.kemer = 1.0,
    this.esik = 1.0,
  });

  final Color renk;
  final double kilitTasi;
  final double kemer;
  final double esik;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 260, size.height / 340);

    final Paint dis = Paint()
      ..color = renk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final Paint ic = Paint()
      ..color = renk.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    if (kemer > 0) {
      _yarimKemerler(canvas, const Offset(130, 130), 122, 332, kemer, dis);
      _yarimKemerler(canvas, const Offset(130, 132), 108, 332, kemer, ic);
    }

    if (esik > 0) {
      final double yari = 130 * esik;
      canvas.drawLine(Offset(130 - yari, 332), Offset(130 + yari, 332), dis);
    }

    if (kilitTasi > 0) {
      final Path kilit = Path()
        ..moveTo(130, 5)
        ..lineTo(141, 16)
        ..lineTo(130, 27)
        ..lineTo(119, 16)
        ..close();
      canvas.save();
      canvas.translate(130, 16);
      canvas.scale(0.6 + 0.4 * kilitTasi);
      canvas.translate(-130, -16);
      canvas.drawPath(kilit, Paint()..color = renk.withValues(alpha: kilitTasi));
      canvas.restore();
    }

    canvas.restore();
  }

  /// Kemeri tepeden başlayıp iki yana doğru, [oran] kadar çizer.
  static void _yarimKemerler(
    Canvas canvas,
    Offset merkez,
    double yaricap,
    double tabanY,
    double oran,
    Paint boya,
  ) {
    final Rect daire = Rect.fromCircle(center: merkez, radius: yaricap);
    final Offset tepe = Offset(merkez.dx, merkez.dy - yaricap);
    final Path sol = Path()
      ..moveTo(tepe.dx, tepe.dy)
      ..arcTo(daire, -math.pi / 2, -math.pi / 2, false)
      ..lineTo(merkez.dx - yaricap, tabanY);
    final Path sag = Path()
      ..moveTo(tepe.dx, tepe.dy)
      ..arcTo(daire, -math.pi / 2, math.pi / 2, false)
      ..lineTo(merkez.dx + yaricap, tabanY);

    for (final Path yol in <Path>[sol, sag]) {
      if (oran >= 1) {
        canvas.drawPath(yol, boya);
        continue;
      }
      for (final metrik in yol.computeMetrics()) {
        canvas.drawPath(metrik.extractPath(0, metrik.length * oran), boya);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CerceveBoyaci eski) {
    return eski.renk != renk ||
        eski.kilitTasi != kilitTasi ||
        eski.kemer != kemer ||
        eski.esik != esik;
  }
}

/// Kapak fotoğrafı yokken sağ alttan yükselen çift kemer (306 × 132 tasarımına göre).
class KapakKemerBoyaci extends CustomPainter {
  const KapakKemerBoyaci({required this.renk});

  final Color renk;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0 || size.width <= 0) {
      return;
    }
    final double olcek = size.height / 132;
    canvas.save();
    canvas.translate(size.width - 306 * olcek, 0);
    canvas.scale(olcek, olcek);
    canvas.drawPath(
      _kemer(183, 303, 78, 132),
      Paint()
        ..color = renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawPath(
      _kemer(197, 289, 82, 132),
      Paint()
        ..color = renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.restore();
  }

  static Path _kemer(double sol, double sag, double merkezY, double taban) {
    final double yaricap = (sag - sol) / 2;
    final Offset merkez = Offset(sol + yaricap, merkezY);
    return Path()
      ..moveTo(sol, taban)
      ..lineTo(sol, merkezY)
      ..arcTo(Rect.fromCircle(center: merkez, radius: yaricap), math.pi, math.pi, false)
      ..lineTo(sag, taban);
  }

  @override
  bool shouldRepaint(covariant KapakKemerBoyaci eski) => eski.renk != renk;
}
