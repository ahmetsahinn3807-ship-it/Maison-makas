import 'package:flutter/cupertino.dart' show CupertinoPicker, FixedExtentScrollController;
import 'package:flutter/material.dart';

import 'renkler.dart';
import 'tema.dart';

/// Hizmet ve galeri kategorileri (veritabanındaki adlarla). Vitrinde bu sırayla gösterilir.
enum HizmetKategorisi {
  sac('sac', 'Saç'),
  sakal('sakal', 'Sakal'),
  renk('renk', 'Renk'),
  bakim('bakim', 'Bakım'),
  cocuk('cocuk', 'Çocuk'),
  diger('diger', 'Diğer');

  const HizmetKategorisi(this.kimlik, this.ad);

  /// Veritabanındaki değer.
  final String kimlik;

  /// Ekranda görünen ad.
  final String ad;

  static HizmetKategorisi kimliktenBul(Object? kimlik) {
    for (final HizmetKategorisi k in HizmetKategorisi.values) {
      if (k.kimlik == kimlik) {
        return k;
      }
    }
    return HizmetKategorisi.diger;
  }
}

/// Türkçe büyük harf: "Diğer" → "DİĞER" (Dart'ın toUpperCase'i i'yi I yapar).
String maisonBuyukHarf(String metin) => metin.replaceAll('i', 'İ').toUpperCase();

/// Kullanıcının yazdığı fiyatı okur: "400", "1.250", "250,50", "12.5". Okunamazsa null.
double? maisonFiyatOku(String metin) {
  String m = metin.replaceAll(RegExp(r'[\s₺€TLtl]'), '');
  if (m.isEmpty) {
    return null;
  }
  if (m.contains(',')) {
    m = m.replaceAll('.', '').replaceAll(',', '.');
  } else if (m.contains('.')) {
    final List<String> parcalar = m.split('.');
    final bool binlik = parcalar.length > 2 || (parcalar.length == 2 && parcalar.last.length == 3);
    if (binlik) {
      m = m.replaceAll('.', '');
    }
  }
  final double? deger = double.tryParse(m);
  if (deger == null || deger.isNaN || deger.isInfinite || deger < 0) {
    return null;
  }
  return (deger * 100).roundToDouble() / 100;
}

/// Fiyatı düzenleme alanına yazılacak biçimde verir: 400 → "400", 250.5 → "250,50".
String maisonFiyatYaz(double fiyat) {
  final bool tam = fiyat == fiyat.roundToDouble();
  return tam ? fiyat.round().toString() : fiyat.toStringAsFixed(2).replaceAll('.', ',');
}

const List<String> _gunAdlari = <String>[
  'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
];
const List<String> _gunKisa = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// 1 = Pazartesi … 7 = Pazar
String maisonGunAdi(int gun) => _gunAdlari[(gun - 1).clamp(0, 6).toInt()];

/// 1 = Pzt … 7 = Paz
String maisonGunKisa(int gun) => _gunKisa[(gun - 1).clamp(0, 6).toInt()];

/// Gece yarısından dakikayı saate çevirir: 545 → "09:05", 1440 → "24:00".
String maisonDakikaMetni(int dakika) {
  final int d = dakika.clamp(0, 1440).toInt();
  return '${(d ~/ 60).toString().padLeft(2, '0')}:${(d % 60).toString().padLeft(2, '0')}';
}

/// "09:00", "09:00:00" ya da "24:00:00" → gece yarısından dakika. Okunamazsa null.
int? maisonDakikaOku(Object? deger) {
  if (deger is! String) {
    return null;
  }
  final List<String> parcalar = deger.trim().split(':');
  if (parcalar.length < 2) {
    return null;
  }
  final int? sa = int.tryParse(parcalar[0]);
  final int? dk = int.tryParse(parcalar[1]);
  if (sa == null || dk == null || sa < 0 || sa > 24 || dk < 0 || dk > 59) {
    return null;
  }
  final int toplam = sa * 60 + dk;
  return toplam > 1440 ? null : toplam;
}

/// Saatin ardına gelen bulunma eki: 20:00'de, 13:00'te, 09:30'da, 14:40'ta.
String maisonSaatEki(int dakika) {
  final int sa = dakika ~/ 60;
  final int dk = dakika % 60;
  final int n = dk == 0 ? sa : dk;
  const Map<int, String> birler = <int, String>{
    1: 'de', 2: 'de', 3: 'te', 4: 'te', 5: 'te', 6: 'da', 7: 'de', 8: 'de', 9: 'da',
  };
  const Map<int, String> onlar = <int, String>{0: 'da', 10: 'da', 20: 'de', 30: 'da', 40: 'ta', 50: 'de'};
  final String ek = n % 10 != 0 ? birler[n % 10]! : (onlar[n] ?? 'da');
  return "${maisonDakikaMetni(dakika)}'$ek";
}

/// Haftalık çalışma takviminde bir aralık. Saatler gece yarısından dakikadır (bitiş 1440'a kadar).
@immutable
class CalismaAraligi {
  const CalismaAraligi({required this.gun, required this.baslangic, required this.bitis});

  factory CalismaAraligi.json(Map<String, dynamic> m) {
    return CalismaAraligi(
      gun: (m['gun'] as num?)?.toInt() ?? 1,
      baslangic: maisonDakikaOku(m['baslangic']) ?? 0,
      bitis: maisonDakikaOku(m['bitis']) ?? 0,
    );
  }

  /// 1 = Pazartesi … 7 = Pazar
  final int gun;
  final int baslangic;
  final int bitis;

  Map<String, dynamic> json() => <String, dynamic>{
        'gun': gun,
        'baslangic': maisonDakikaMetni(baslangic),
        'bitis': maisonDakikaMetni(bitis),
      };

  /// "09:00–13:00"
  String get metin => '${maisonDakikaMetni(baslangic)}–${maisonDakikaMetni(bitis)}';

  bool get gecerli => gun >= 1 && gun <= 7 && bitis > baslangic && baslangic >= 0 && bitis <= 1440;

  CalismaAraligi copyWith({int? gun, int? baslangic, int? bitis}) {
    return CalismaAraligi(
      gun: gun ?? this.gun,
      baslangic: baslangic ?? this.baslangic,
      bitis: bitis ?? this.bitis,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CalismaAraligi && other.gun == gun && other.baslangic == baslangic && other.bitis == bitis;

  @override
  int get hashCode => Object.hash(gun, baslangic, bitis);
}

/// Aralıkları gün ve saat sırasına dizer.
List<CalismaAraligi> maisonAralikSirala(Iterable<CalismaAraligi> araliklar) {
  final List<CalismaAraligi> liste = araliklar.toList();
  liste.sort((CalismaAraligi a, CalismaAraligi b) {
    final int g = a.gun.compareTo(b.gun);
    return g != 0 ? g : a.baslangic.compareTo(b.baslangic);
  });
  return liste;
}

/// Bir günün aralıklarında sorun varsa açıklaması (çakışma, ters saat), yoksa null.
String? maisonGunDenetle(List<CalismaAraligi> gunun) {
  final List<CalismaAraligi> sirali = maisonAralikSirala(gunun);
  for (final CalismaAraligi a in sirali) {
    if (a.bitis <= a.baslangic) {
      return '${maisonGunAdi(a.gun)}: bitiş saati başlangıçtan sonra olmalı.';
    }
  }
  for (int i = 1; i < sirali.length; i++) {
    if (sirali[i].baslangic < sirali[i - 1].bitis) {
      return '${maisonGunAdi(sirali[i].gun)}: aralıklar çakışıyor.';
    }
  }
  if (sirali.length > 4) {
    return '${maisonGunAdi(sirali.first.gun)}: bir güne en çok 4 aralık girilebilir.';
  }
  return null;
}

/// Haftayı kısa satırlara özetler: aynı saatlerdeki ardışık günler birleşir.
/// [Pzt–Cum 09:00–13:00, 14:00–20:00] [Cmt 10:00–18:00]
List<String> maisonHaftaOzeti(Iterable<CalismaAraligi> araliklar) {
  final List<CalismaAraligi> sirali = maisonAralikSirala(araliklar);
  String gunMetni(int gun) => sirali.where((CalismaAraligi a) => a.gun == gun).map((CalismaAraligi a) => a.metin).join(', ');
  final List<String> satirlar = <String>[];
  int gun = 1;
  while (gun <= 7) {
    final String metin = gunMetni(gun);
    if (metin.isEmpty) {
      gun++;
      continue;
    }
    int son = gun;
    while (son + 1 <= 7 && gunMetni(son + 1) == metin) {
      son++;
    }
    final String gunler = son == gun ? maisonGunKisa(gun) : '${maisonGunKisa(gun)}–${maisonGunKisa(son)}';
    satirlar.add('$gunler $metin');
    gun = son + 1;
  }
  return satirlar;
}

/// Salonun "şu an açık mı" bilgisi.
@immutable
class SalonDurumu {
  const SalonDurumu({required this.acik, required this.metin});

  final bool acik;

  /// "Şu an açık · 20:00'de kapanır" ya da "Şu an kapalı · Yarın 09:00'da açılır"
  final String metin;
}

/// Vitrinde gösterilen haftalık açık saatler (aktif ustaların saatleri birleşmiş hâliyle).
@immutable
class SalonSaatleri {
  SalonSaatleri({required this.araliklar, this.yerelSimdi, DateTime? alindi}) : alindi = alindi ?? DateTime.now();

  /// `salon_saatleri` fonksiyonunun yanıtından okur.
  factory SalonSaatleri.json(Object? kaynak) {
    if (kaynak is! Map) {
      return SalonSaatleri(araliklar: const <CalismaAraligi>[]);
    }
    final Object? saatler = kaynak['saatler'];
    final List<CalismaAraligi> araliklar = <CalismaAraligi>[];
    if (saatler is List) {
      for (final Object? s in saatler) {
        if (s is Map<String, dynamic>) {
          final CalismaAraligi a = CalismaAraligi.json(s);
          if (a.gecerli) {
            araliklar.add(a);
          }
        }
      }
    }
    final Object? simdi = kaynak['yerel_simdi'];
    return SalonSaatleri(
      araliklar: maisonAralikSirala(araliklar),
      yerelSimdi: simdi is String ? DateTime.tryParse(simdi) : null,
    );
  }

  final List<CalismaAraligi> araliklar;

  /// Salonun saat dilimindeki yerel saat (sunucudan alındığı an).
  final DateTime? yerelSimdi;

  /// Telefonun saatiyle alındığı an.
  final DateTime alindi;

  bool get bos => araliklar.isEmpty;

  List<CalismaAraligi> gunun(int gun) => araliklar.where((CalismaAraligi a) => a.gun == gun).toList();

  /// Salonun şu anki yerel saati: sunucudan alınan saate o andan beri geçen süre eklenir.
  DateTime simdi([DateTime? cihazSimdi]) {
    final DateTime cihaz = cihazSimdi ?? DateTime.now();
    final DateTime? yerel = yerelSimdi;
    return yerel == null ? cihaz : yerel.add(cihaz.difference(alindi));
  }

  /// Şu an açık mı, ne zaman kapanır ya da açılır. Saat girilmemişse null.
  SalonDurumu? durum([DateTime? cihazSimdi]) {
    if (bos) {
      return null;
    }
    final DateTime an = simdi(cihazSimdi);
    final int bugun = an.weekday;
    final int dakika = an.hour * 60 + an.minute;
    for (final CalismaAraligi a in gunun(bugun)) {
      if (dakika >= a.baslangic && dakika < a.bitis) {
        return SalonDurumu(acik: true, metin: 'Şu an açık · ${maisonSaatEki(a.bitis)} kapanır');
      }
    }
    for (final CalismaAraligi a in gunun(bugun)) {
      if (a.baslangic > dakika) {
        return SalonDurumu(acik: false, metin: 'Şu an kapalı · ${maisonSaatEki(a.baslangic)} açılır');
      }
    }
    for (int ileri = 1; ileri <= 7; ileri++) {
      final int gun = (bugun - 1 + ileri) % 7 + 1;
      final List<CalismaAraligi> o = gunun(gun);
      if (o.isNotEmpty) {
        final String ne = ileri == 1 ? 'Yarın' : maisonGunAdi(gun);
        return SalonDurumu(acik: false, metin: 'Şu an kapalı · $ne ${maisonSaatEki(o.first.baslangic)} açılır');
      }
    }
    return null;
  }
}

/// 15 dakikalık adımlarla saat seçtiren alt sayfa. Seçilen saat (dakika) ya da vazgeçilirse null.
Future<int?> maisonSaatSec(
  BuildContext context, {
  required String baslik,
  required int secili,
  int enAz = 0,
  int enCok = 1440,
  int adim = 15,
}) {
  final MaisonRenkler r = MaisonRenkler.of(context);
  final List<int> secenekler = <int>[
    for (int d = enAz; d <= enCok; d += adim) d,
  ];
  if (secenekler.isEmpty) {
    return Future<int?>.value(null);
  }
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: r.kart,
    showDragHandle: true,
    builder: (BuildContext context) => _SaatSecici(baslik: baslik, secenekler: secenekler, secili: secili),
  );
}

class _SaatSecici extends StatefulWidget {
  const _SaatSecici({required this.baslik, required this.secenekler, required this.secili});

  final String baslik;
  final List<int> secenekler;
  final int secili;

  @override
  State<_SaatSecici> createState() => _SaatSeciciState();
}

class _SaatSeciciState extends State<_SaatSecici> {
  late int _secim = _enYakin();
  late final FixedExtentScrollController _kaydirma = FixedExtentScrollController(initialItem: _secim);

  int _enYakin() {
    int enYakin = 0;
    for (int i = 0; i < widget.secenekler.length; i++) {
      if ((widget.secenekler[i] - widget.secili).abs() < (widget.secenekler[enYakin] - widget.secili).abs()) {
        enYakin = i;
      }
    }
    return enYakin;
  }

  @override
  void dispose() {
    _kaydirma.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(widget.baslik, style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                itemExtent: 44,
                scrollController: _kaydirma,
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    color: r.vurguYumusak,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSelectedItemChanged: (int i) => _secim = i,
                children: <Widget>[
                  for (final int d in widget.secenekler)
                    Center(
                      child: Text(
                        maisonDakikaMetni(d),
                        style: maisonGovde(22, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.2),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(widget.secenekler[_secim]),
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haftalık saatleri gün gün gösteren tablo (vitrinde ve Makas Pro'da).
class MaisonHaftalikSaatler extends StatelessWidget {
  const MaisonHaftalikSaatler({super.key, required this.araliklar, this.bugun});

  final List<CalismaAraligi> araliklar;

  /// Vurgulanacak gün (1–7); null ise vurgulanmaz.
  final int? bugun;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Column(
      children: <Widget>[
        for (int gun = 1; gun <= 7; gun++)
          Builder(
            builder: (BuildContext context) {
              final List<CalismaAraligi> o =
                  araliklar.where((CalismaAraligi a) => a.gun == gun).toList();
              final bool vurgu = gun == bugun;
              final TextStyle stil = maisonGovde(
                15,
                renk: o.isEmpty ? r.soluk : r.yazi,
                kalinlik: vurgu ? FontWeight.w600 : FontWeight.w400,
                yukseklik: 1.3,
              );
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 116,
                      child: Row(
                        children: <Widget>[
                          Flexible(child: Text(maisonGunAdi(gun), style: stil)),
                          if (vurgu) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: r.vurgu, shape: BoxShape.circle),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        o.isEmpty ? 'Kapalı' : o.map((CalismaAraligi a) => a.metin).join(', '),
                        textAlign: TextAlign.end,
                        style: stil,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Haftalık saatleri alt sayfada açar.
Future<void> maisonHaftalikSaatleriGoster(
  BuildContext context, {
  required String baslik,
  required SalonSaatleri saatler,
}) {
  final MaisonRenkler r = MaisonRenkler.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: r.kart,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      final SalonDurumu? d = saatler.durum();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(baslik, style: maisonBaslik(26, renk: r.yazi, kalinlik: FontWeight.w600)),
              if (d != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(d.metin, style: maisonGovde(14, renk: d.acik ? r.vurgu : r.soluk, yukseklik: 1.4)),
              ],
              const SizedBox(height: 12),
              MaisonHaftalikSaatler(araliklar: saatler.araliklar, bugun: saatler.simdi().weekday),
            ],
          ),
        ),
      );
    },
  );
}
