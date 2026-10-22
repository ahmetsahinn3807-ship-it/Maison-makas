import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FileObject, FileOptions, SearchOptions, SupabaseClient;

import 'bilesenler.dart';
import 'dil.dart';
import 'foto.dart';
import 'oturum.dart';
import 'renkler.dart';
import 'tema.dart';

/// Seçilmiş, küçültülmüş ve yüklemeye hazır fotoğraf.
@immutable
class SecilenFoto {
  const SecilenFoto(this.baytlar, this.turu, this.uzanti);

  final Uint8List baytlar;

  /// MIME türü, ör. `image/jpeg`.
  final String turu;

  /// Dosya uzantısı, ör. `jpg`.
  final String uzanti;
}

/// Fotoğrafın nerede kullanılacağına göre en uzun kenarı (piksel) ve JPEG kalitesi.
enum FotoBoyu {
  kapak(1600, 82),
  galeri(1440, 82),
  avatar(640, 85);

  const FotoBoyu(this.enUzun, this.kalite);

  final int enUzun;
  final int kalite;
}

/// Fotoğraf için kullanıcının seçtiği işlem.
enum FotoIslemi { galeri, kamera, odak, kaldir }

/// "Galeriden seç · Fotoğraf çek · Odağı ayarla · Kaldır" alt sayfası.
Future<FotoIslemi?> maisonFotoIslemiSor(
  BuildContext context, {
  required String baslik,
  bool kaldirilabilir = false,
  bool odakAyarlanabilir = false,
}) {
  final MaisonRenkler r = MaisonRenkler.of(context);
  final Color hataRengi = Theme.of(context).colorScheme.error;
  return showModalBottomSheet<FotoIslemi>(
    context: context,
    backgroundColor: r.kart,
    showDragHandle: true,
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(baslik, style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: r.yazi),
              title: Text(dl('Galeriden seç', 'Choose from gallery'), style: maisonGovde(15, renk: r.yazi)),
              onTap: () => Navigator.of(context).pop(FotoIslemi.galeri),
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: r.yazi),
              title: Text(dl('Fotoğraf çek', 'Take a photo'), style: maisonGovde(15, renk: r.yazi)),
              onTap: () => Navigator.of(context).pop(FotoIslemi.kamera),
            ),
            if (odakAyarlanabilir)
              ListTile(
                leading: Icon(Icons.center_focus_strong_outlined, color: r.yazi),
                title: Text(dl('Görünen kısmı ayarla', 'Adjust the visible area'), style: maisonGovde(15, renk: r.yazi)),
                onTap: () => Navigator.of(context).pop(FotoIslemi.odak),
              ),
            if (kaldirilabilir)
              ListTile(
                leading: Icon(Icons.delete_outline, color: hataRengi),
                title: Text(dl('Fotoğrafı kaldır', 'Remove photo'), style: maisonGovde(15, renk: hataRengi)),
                onTap: () => Navigator.of(context).pop(FotoIslemi.kaldir),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

final ImagePicker _secici = ImagePicker();

/// Galeriden ya da kameradan tek fotoğraf seçer ve küçültür. Vazgeçilirse null.
Future<SecilenFoto?> maisonFotoSec(FotoIslemi kaynak, FotoBoyu boy) async {
  final XFile? dosya = await _secici.pickImage(
    source: kaynak == FotoIslemi.kamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: boy.enUzun.toDouble(),
    maxHeight: boy.enUzun.toDouble(),
    imageQuality: boy.kalite,
    requestFullMetadata: false,
  );
  if (dosya == null) {
    return null;
  }
  return _hazirla(await dosya.readAsBytes());
}

/// Galeriden birden çok fotoğraf seçer (en çok [sinir] tane).
Future<List<SecilenFoto>> maisonFotolarSec(FotoBoyu boy, {int sinir = 10}) async {
  final List<XFile> dosyalar = await _secici.pickMultiImage(
    maxWidth: boy.enUzun.toDouble(),
    maxHeight: boy.enUzun.toDouble(),
    imageQuality: boy.kalite,
    // Seçici 2'den küçük sınırı kabul etmez; fazlası aşağıda kırpılır.
    limit: math.max(2, sinir),
    requestFullMetadata: false,
  );
  final List<SecilenFoto> sonuc = <SecilenFoto>[];
  for (final XFile dosya in dosyalar.take(sinir)) {
    sonuc.add(_hazirla(await dosya.readAsBytes()));
  }
  return sonuc;
}

SecilenFoto _hazirla(Uint8List b) {
  if (b.length > 6 * 1024 * 1024) {
    throw MaisonHata(dl('Fotoğraf çok büyük; en çok 6 MB olabilir.', 'The photo is too large; the limit is 6 MB.'));
  }
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return SecilenFoto(b, 'image/jpeg', 'jpg');
  }
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return SecilenFoto(b, 'image/png', 'png');
  }
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return SecilenFoto(b, 'image/webp', 'webp');
  }
  throw MaisonHata(dl('Bu fotoğraf biçimi desteklenmiyor. JPG ya da PNG bir fotoğraf seç.', 'This photo format is not supported. Choose a JPG or PNG photo.'));
}

/// Fotoğrafı kovaya yükler ve herkese açık adresini döndürür.
///
/// Dosya adı her yüklemede yenidir (`<klasör>/<ad>-<zaman><rastgele>.<uzantı>`);
/// böylece eski adres önbellekte kalsa da yeni fotoğraf hemen görünür.
Future<String> maisonFotoYukle(
  SupabaseClient istemci, {
  required String kova,
  required String klasor,
  required String ad,
  required SecilenFoto foto,
}) async {
  final String ek = math.Random().nextInt(1 << 20).toRadixString(36);
  final String yol = '$klasor/$ad-${DateTime.now().millisecondsSinceEpoch}$ek.${foto.uzanti}';
  await istemci.storage.from(kova).uploadBinary(
        yol,
        foto.baytlar,
        fileOptions: FileOptions(cacheControl: '31536000', contentType: foto.turu),
      );
  return istemci.storage.from(kova).getPublicUrl(yol);
}

/// Herkese açık adresten kova ve dosya yolunu bulur
/// (`…/storage/v1/object/public/<kova>/<yol>`); başka bir adresse null.
({String kova, String yol})? maisonFotoKonumu(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }
  final Uri? adres = Uri.tryParse(url);
  if (adres == null) {
    return null;
  }
  final List<String> parcalar = adres.pathSegments;
  final int i = parcalar.indexOf('public');
  if (i < 0 || i + 2 >= parcalar.length || i < 2 || parcalar[i - 1] != 'object') {
    return null;
  }
  return (kova: parcalar[i + 1], yol: parcalar.sublist(i + 2).join('/'));
}

/// Adresi bilinen fotoğrafı siler. Hata olursa sessiz geçer: eski dosya kalır ama ekran bozulmaz.
Future<void> maisonFotoSil(SupabaseClient istemci, String? url) async {
  final ({String kova, String yol})? konum = maisonFotoKonumu(url);
  if (konum == null) {
    return;
  }
  try {
    await istemci.storage.from(konum.kova).remove(<String>[konum.yol]);
  } catch (_) {
    // Silinemeyen dosya yalnız yer kaplar.
  }
}

/// Bir klasördeki bütün dosyaları (alt klasörler dahil) siler. Hesap silinirken kullanılır.
Future<void> maisonKlasoruBosalt(SupabaseClient istemci, String kova, String klasor) async {
  try {
    final List<FileObject> ogeler = await istemci.storage
        .from(kova)
        .list(path: klasor, searchOptions: const SearchOptions(limit: 1000));
    final List<String> dosyalar = <String>[];
    for (final FileObject oge in ogeler) {
      if (oge.id == null) {
        await maisonKlasoruBosalt(istemci, kova, '$klasor/${oge.name}');
      } else {
        dosyalar.add('$klasor/${oge.name}');
      }
    }
    for (int i = 0; i < dosyalar.length; i += 100) {
      await istemci.storage.from(kova).remove(dosyalar.sublist(i, math.min(i + 100, dosyalar.length)));
    }
  } catch (_) {
    // Kalan dosyalar yalnız yer kaplar; hesap silme yine sürer.
  }
}

/// Kapak fotoğrafının hangi kısmının görüneceğini seçtiren ekranı açar.
/// Kaydedilirse 0–1 aralığında odak noktası, vazgeçilirse null döner.
Future<Offset?> maisonOdakSec(
  BuildContext context, {
  required ImageProvider resim,
  Offset baslangic = const Offset(0.5, 0.5),
  double oran = 4 / 3,
  String? baslik,
}) {
  return Navigator.of(context).push<Offset>(
    MaterialPageRoute<Offset>(
      fullscreenDialog: true,
      builder: (BuildContext context) => _OdakSecici(
        resim: resim,
        baslangic: baslangic,
        oran: oran,
        baslik: baslik ?? dl('Kapağı ayarla', 'Adjust cover'),
      ),
    ),
  );
}

class _OdakSecici extends StatefulWidget {
  const _OdakSecici({
    required this.resim,
    required this.baslangic,
    required this.oran,
    required this.baslik,
  });

  final ImageProvider resim;
  final Offset baslangic;
  final double oran;
  final String baslik;

  @override
  State<_OdakSecici> createState() => _OdakSeciciState();
}

class _OdakSeciciState extends State<_OdakSecici> {
  late Offset _odak = widget.baslangic;
  Size? _boyut;
  ImageStream? _akis;
  late final ImageStreamListener _dinleyici = ImageStreamListener(
    (ImageInfo bilgi, bool _) {
      if (mounted) {
        setState(() => _boyut = Size(bilgi.image.width.toDouble(), bilgi.image.height.toDouble()));
      }
    },
    onError: (Object _, StackTrace? __) {
      if (mounted) {
        setState(() => _boyut = const Size(4, 3));
      }
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_akis == null) {
      final ImageStream akis = widget.resim.resolve(createLocalImageConfiguration(context));
      akis.addListener(_dinleyici);
      _akis = akis;
    }
  }

  @override
  void dispose() {
    _akis?.removeListener(_dinleyici);
    super.dispose();
  }

  void _dokun(Offset yer, Size alan) {
    final Size? b = _boyut;
    if (b == null || b.width <= 0 || b.height <= 0) {
      return;
    }
    final double olcek = math.min(alan.width / b.width, alan.height / b.height);
    final double w = b.width * olcek;
    final double h = b.height * olcek;
    final double sol = (alan.width - w) / 2;
    final double ust = (alan.height - h) / 2;
    setState(() {
      _odak = Offset(
        ((yer.dx - sol) / w).clamp(0.0, 1.0).toDouble(),
        ((yer.dy - ust) / h).clamp(0.0, 1.0).toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Size? b = _boyut;
    return Scaffold(
      backgroundColor: r.zemin,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MaisonUstSatir(
                sol: MaisonYuvarlakDugme(
                  ikon: Icons.close,
                  etiket: dl('Vazgeç', 'Cancel'),
                  onTap: () => Navigator.of(context).pop(),
                ),
                baslik: widget.baslik,
                sag: TextButton(
                  onPressed: () => Navigator.of(context).pop(_odak),
                  child: Text(dl('Kaydet', 'Save')),
                ),
              ),
              const SizedBox(height: 18),
              MaisonUstBaslik(dl('ÖNİZLEME', 'PREVIEW')),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: widget.oran,
                  child: Image(
                    image: widget.resim,
                    fit: BoxFit.cover,
                    alignment: maisonOdakHizasi(_odak),
                    gaplessPlayback: true,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                dl('Fotoğrafın görünmesini istediğin yerine dokun ya da parmağını kaydır.', 'Tap or drag to the part of the photo you want to show.'),
                style: maisonGovde(14, renk: r.soluk, yukseklik: 1.45),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: b == null
                    ? const MaisonYukleniyor()
                    : LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints kisit) {
                          final Size alan = Size(kisit.maxWidth, kisit.maxHeight);
                          final double olcek = math.min(alan.width / b.width, alan.height / b.height);
                          final double w = b.width * olcek;
                          final double h = b.height * olcek;
                          final double sol = (alan.width - w) / 2;
                          final double ust = (alan.height - h) / 2;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (TapDownDetails d) => _dokun(d.localPosition, alan),
                            onPanUpdate: (DragUpdateDetails d) => _dokun(d.localPosition, alan),
                            child: Stack(
                              children: <Widget>[
                                Positioned(
                                  left: sol,
                                  top: ust,
                                  width: w,
                                  height: h,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image(image: widget.resim, fit: BoxFit.fill, gaplessPlayback: true),
                                  ),
                                ),
                                Positioned(
                                  left: sol + _odak.dx * w - 22,
                                  top: ust + _odak.dy * h - 22,
                                  child: IgnorePointer(
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        color: r.vurgu.withValues(alpha: 0.35),
                                        boxShadow: const <BoxShadow>[
                                          BoxShadow(color: Color(0x66000000), blurRadius: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
