import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../isletme.dart';
import '../salon.dart';
import 'randevu_islemleri.dart';

/// Takvim: günlük görünümde her usta bir sütun; haftalık görünümde gün gün liste.
class TakvimEkrani extends StatefulWidget {
  const TakvimEkrani({super.key, required this.salon});

  final ProSalon salon;

  @override
  State<TakvimEkrani> createState() => _TakvimEkraniState();
}

/// Takvimdeki bir sütun.
@immutable
class _Sutun {
  const _Sutun({required this.id, required this.ad, this.fotoUrl, this.basHarfler = ''});

  final String id;
  final String ad;
  final String? fotoUrl;
  final String basHarfler;
}

class _TakvimEkraniState extends State<TakvimEkrani> {
  static const double _dakikaBoyu = 1.1;
  static const double _saatSutunu = 52;

  DateTime _gun = _bugun();

  /// 0 = gün, 1 = hafta
  int _gorunum = 0;

  TakvimTanimlari? _tanim;
  Map<String, List<CalismaAraligi>> _saatler = <String, List<CalismaAraligi>>{};
  List<TakvimKaydi>? _kayitlar;
  Object? _hata;
  int _sorgu = 0;

  static DateTime _bugun() {
    final DateTime s = DateTime.now();
    return DateTime(s.year, s.month, s.day);
  }

  static bool _ayniGun(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime get _haftaBasi => DateTime(_gun.year, _gun.month, _gun.day - (_gun.weekday - 1));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tanim == null && _hata == null && _kayitlar == null) {
      _ilkYukleme();
    }
  }

  Future<void> _ilkYukleme() async {
    try {
      final MaisonOturum oturum = OturumKapsami.oku(context);
      final SupabaseClient i = await oturum.istemciGerekli();
      final List<Object?> sonuc = await Future.wait<Object?>(<Future<Object?>>[
        TakvimTanimlari.yukle(i, widget.salon, oturum.kullanici?.id),
        i.from('calisma_saatleri').select('usta_id, gun, baslangic, bitis').eq('salon_id', widget.salon.id),
      ]);
      final Map<String, List<CalismaAraligi>> saatler = <String, List<CalismaAraligi>>{};
      final Object? satirlar = sonuc[1];
      if (satirlar is List) {
        for (final Map<String, dynamic> m in satirlar.whereType<Map<String, dynamic>>()) {
          final Object? usta = m['usta_id'];
          if (usta is String) {
            (saatler[usta] ??= <CalismaAraligi>[]).add(CalismaAraligi.json(m));
          }
        }
      }
      if (mounted) {
        setState(() {
          _tanim = sonuc[0]! as TakvimTanimlari;
          _saatler = saatler;
        });
      }
      await _kayitlariYukle();
    } catch (hata) {
      if (mounted) {
        setState(() => _hata = hata);
      }
    }
  }

  Future<void> _kayitlariYukle() async {
    final int sorgu = ++_sorgu;
    final DateTime bas = _gorunum == 0 ? _gun : _haftaBasi;
    final DateTime son = DateTime(bas.year, bas.month, bas.day + (_gorunum == 0 ? 1 : 7));
    try {
      final SupabaseClient i = await OturumKapsami.oku(context).istemciGerekli();
      final Object? sonuc = await i.rpc('salon_takvimi', params: <String, dynamic>{
        'p_salon': widget.salon.id,
        'p_bas': bas.toUtc().toIso8601String(),
        'p_son': son.toUtc().toIso8601String(),
      });
      if (!mounted || sorgu != _sorgu) {
        return;
      }
      setState(() {
        _kayitlar = sonuc is List
            ? sonuc.whereType<Map<String, dynamic>>().map(TakvimKaydi.json).toList()
            : <TakvimKaydi>[];
        _hata = null;
      });
    } catch (hata) {
      if (mounted && sorgu == _sorgu) {
        setState(() => _hata = hata);
      }
    }
  }

  void _gunDegistir(int fark) {
    setState(() {
      _gun = DateTime(_gun.year, _gun.month, _gun.day + fark);
      _kayitlar = null;
    });
    _kayitlariYukle();
  }

  void _bugunGit() {
    setState(() {
      _gun = _bugun();
      _kayitlar = null;
    });
    _kayitlariYukle();
  }

  void _gorunumSec(int gorunum) {
    if (gorunum == _gorunum) {
      return;
    }
    setState(() {
      _gorunum = gorunum;
      _kayitlar = null;
    });
    _kayitlariYukle();
  }

  Future<void> _ayrinti(TakvimKaydi k) async {
    if (await randevuAyrintisiAc(context, k) && mounted) {
      await _kayitlariYukle();
    }
  }

  Future<void> _yeniKayit({DateTime? zaman, String? ustaId}) async {
    final TakvimTanimlari? tanim = _tanim;
    if (tanim == null) {
      return;
    }
    if (await kapidanGelenAc(context, salon: widget.salon, tanimlar: tanim, zaman: zaman, ustaId: ustaId) &&
        mounted) {
      await _kayitlariYukle();
    }
  }

  Future<void> _molaEkle({required int dakika, String? ustaId}) async {
    final TakvimTanimlari? tanim = _tanim;
    if (tanim == null) {
      return;
    }
    if (await blokEkleAc(context, tanimlar: tanim, gun: _gun, baslangic: dakika, ustaId: ustaId) && mounted) {
      await _kayitlariYukle();
    }
  }

  /// Boş bir yere dokununca: o saate randevu ya da mola.
  Future<void> _bosaDokun(_Sutun sutun, int dakika) async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final int yuvarlak = (dakika ~/ 15) * 15;
    final String saat = maisonDakikaMetni(yuvarlak);
    final String? secim = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '${sutun.ad} · $saat',
                style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: Icon(Icons.person_add_alt, color: r.yazi),
              title: Text(dl('Randevu yaz', 'Add booking'), style: maisonGovde(15, renk: r.yazi)),
              subtitle: Text(dl('Kapıdan gelen ya da telefonla arayan', 'Walk-in or phone booking'), style: maisonGovde(12, renk: r.soluk)),
              onTap: () => Navigator.of(context).pop('randevu'),
            ),
            ListTile(
              leading: Icon(Icons.free_breakfast_outlined, color: r.yazi),
              title: Text(dl('Mola ya da izin ekle', 'Add break or time off'), style: maisonGovde(15, renk: r.yazi)),
              onTap: () => Navigator.of(context).pop('mola'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || secim == null) {
      return;
    }
    if (secim == 'randevu') {
      await _yeniKayit(zaman: gununSaati(_gun, yuvarlak), ustaId: sutun.id);
    } else {
      await _molaEkle(dakika: yuvarlak, ustaId: sutun.id);
    }
  }

  // ---------------------------------------------------------------- Ekran

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Object? hata = _hata;
    final List<TakvimKaydi>? kayitlar = _kayitlar;
    final TakvimTanimlari? tanim = _tanim;
    final bool bugun = _ayniGun(_gun, _bugun());
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonTercih.proPaleti),
      child: Scaffold(
        backgroundColor: r.zemin,
        floatingActionButton: tanim == null || tanim.ustalar.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _yeniKayit(zaman: bugun ? null : gununSaati(_gun, 10 * 60)),
                backgroundColor: r.vurgu,
                foregroundColor: r.vurguUstu,
                icon: const Icon(Icons.person_add_alt),
                label: Text(bugun ? dl('Kapıdan gelen', 'Walk-in') : dl('Randevu yaz', 'Add booking')),
              ),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: MaisonUstSatir(
                  sol: MaisonYuvarlakDugme(
                    ikon: Icons.arrow_back,
                    etiket: dl('Geri', 'Back'),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  baslik: dl('Takvim', 'Calendar'),
                  sag: MaisonYuvarlakDugme(ikon: Icons.refresh, etiket: dl('Yenile', 'Refresh'), onTap: _kayitlariYukle),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: MaisonSekmeSecici(
                  secenekler: <String>[dl('Gün', 'Day'), dl('Hafta', 'Week')],
                  secili: _gorunum,
                  onSec: _gorunumSec,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      tooltip: _gorunum == 0 ? dl('Önceki gün', 'Previous day') : dl('Önceki hafta', 'Previous week'),
                      onPressed: () => _gunDegistir(_gorunum == 0 ? -1 : -7),
                      icon: Icon(Icons.chevron_left, color: r.yazi),
                    ),
                    Expanded(
                      child: Text(
                        _gorunum == 0
                            ? '${maisonGun(_gun)}, ${_gun.day} ${maisonAy(_gun)}'
                            : _haftaMetni(),
                        textAlign: TextAlign.center,
                        style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                      ),
                    ),
                    IconButton(
                      tooltip: _gorunum == 0 ? dl('Sonraki gün', 'Next day') : dl('Sonraki hafta', 'Next week'),
                      onPressed: () => _gunDegistir(_gorunum == 0 ? 1 : 7),
                      icon: Icon(Icons.chevron_right, color: r.yazi),
                    ),
                    TextButton(onPressed: _bugunGit, child: Text(dl('Bugün', 'Today'))),
                  ],
                ),
              ),
              Expanded(
                child: hata != null && kayitlar == null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: MaisonHataKutusu(
                          maisonHataMetni(hata),
                          tekrar: () {
                            setState(() => _hata = null);
                            if (_tanim == null) {
                              _ilkYukleme();
                            } else {
                              _kayitlariYukle();
                            }
                          },
                        ),
                      )
                    : kayitlar == null || tanim == null
                        ? const MaisonYukleniyor()
                        : _gorunum == 0
                            ? _gunGorunumu(r, tanim, kayitlar)
                            : _haftaGorunumu(r, kayitlar),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _haftaMetni() {
    final DateTime bas = _haftaBasi;
    final DateTime son = DateTime(bas.year, bas.month, bas.day + 6);
    return bas.month == son.month
        ? '${bas.day}–${son.day} ${maisonAy(son)}'
        : '${bas.day} ${maisonAy(bas)} – ${son.day} ${maisonAy(son)}';
  }

  // ---------------------------------------------------------------- Gün

  Widget _gunGorunumu(MaisonRenkler r, TakvimTanimlari tanim, List<TakvimKaydi> kayitlar) {
    final List<_Sutun> sutunlar = <_Sutun>[
      for (final ProUsta u in tanim.ustalar) _Sutun(id: u.id, ad: u.ad, fotoUrl: u.fotoUrl, basHarfler: u.basHarfler),
    ];
    for (final TakvimKaydi k in kayitlar) {
      if (!sutunlar.any((_Sutun s) => s.id == k.ustaId)) {
        sutunlar.add(_Sutun(id: k.ustaId, ad: k.ustaAd, basHarfler: k.ustaAd.isEmpty ? 'U' : k.ustaAd.substring(0, 1)));
      }
    }
    if (sutunlar.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          MaisonBosDurum(
            ikon: Icons.groups_outlined,
            baslik: dl('Takvimde usta yok', 'No barbers in the calendar'),
            aciklama: widget.salon.sahibim
                ? dl('Ekip ekranından usta ekle ve çalışma saatlerini gir; takvim ustalara göre sütunlara ayrılır.', 'Add barbers on the Team screen and enter their working hours; the calendar shows a column per barber.')
                : dl('Salon sahibi seni ekibe eklediğinde takvimin burada görünür.', 'Your calendar will appear here once the salon owner adds you to the team.'),
          ),
        ],
      );
    }

    // Görünen saat aralığı: en az 08:00–20:00; çalışma saatleri ve kayıtlar taşarsa genişler.
    final int haftaGunu = _gun.weekday;
    int bas = 8 * 60;
    int son = 20 * 60;
    for (final _Sutun s in sutunlar) {
      for (final CalismaAraligi a in _saatler[s.id] ?? const <CalismaAraligi>[]) {
        if (a.gun == haftaGunu) {
          bas = math.min(bas, a.baslangic);
          son = math.max(son, a.bitis);
        }
      }
    }
    int dakikaOf(DateTime t) {
      if (t.isBefore(_gun)) {
        return 0;
      }
      if (!_ayniGun(t, _gun)) {
        return 1440;
      }
      return t.hour * 60 + t.minute;
    }

    for (final TakvimKaydi k in kayitlar) {
      bas = math.min(bas, dakikaOf(k.baslangic));
      son = math.max(son, dakikaOf(k.bitis));
    }
    bas = (bas ~/ 60) * 60;
    son = math.min(1440, ((son + 59) ~/ 60) * 60);
    final double yukseklik = (son - bas) * _dakikaBoyu;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints kisit) {
        final double kullanilabilir = kisit.maxWidth - _saatSutunu - 16;
        final double sutunGenisligi = math.max(124, kullanilabilir / sutunlar.length);
        final double toplamGenislik = _saatSutunu + sutunGenisligi * sutunlar.length + 16;
        final bool bugun = _ayniGun(_gun, _bugun());
        final DateTime simdi = DateTime.now();
        final int simdiDk = simdi.hour * 60 + simdi.minute;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: toplamGenislik,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Usta başlıkları
                  Padding(
                    padding: const EdgeInsets.only(left: _saatSutunu, top: 10, bottom: 8),
                    child: Row(
                      children: <Widget>[
                        for (final _Sutun s in sutunlar)
                          SizedBox(
                            width: sutunGenisligi,
                            child: Row(
                              children: <Widget>[
                                MaisonAvatar(basHarfler: s.basHarfler, boyut: 34, fotoUrl: s.fotoUrl),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        s.ad,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: maisonGovde(13, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
                                      ),
                                      Text(
                                        _randevuSayisi(
                                          kayitlar.where((TakvimKaydi k) => k.ustaId == s.id && !k.blok && k.durum != 'iptal').length,
                                        ),
                                        style: maisonGovde(11, renk: r.soluk, yukseklik: 1.2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: yukseklik + 12,
                    child: Stack(
                      children: <Widget>[
                        // Sütun zeminleri: çalışma saatleri açık, dışı koyu; boş yere dokununca işlem.
                        for (int i = 0; i < sutunlar.length; i++)
                          Positioned(
                            left: _saatSutunu + i * sutunGenisligi,
                            top: 0,
                            width: sutunGenisligi,
                            height: yukseklik,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (TapUpDetails d) =>
                                  _bosaDokun(sutunlar[i], bas + (d.localPosition.dy / _dakikaBoyu).floor()),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Color.lerp(r.zemin, r.cizgi, 0.35),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Stack(
                                  children: <Widget>[
                                    for (final CalismaAraligi a
                                        in _saatler[sutunlar[i].id] ?? const <CalismaAraligi>[])
                                      if (a.gun == haftaGunu)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: (a.baslangic - bas) * _dakikaBoyu,
                                          height: (a.bitis - a.baslangic) * _dakikaBoyu,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: r.kart,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        // Saat çizgileri ve etiketleri
                        for (int dk = bas; dk <= son; dk += 60)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: (dk - bas) * _dakikaBoyu - 7,
                            height: 14,
                            child: IgnorePointer(
                              child: Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: _saatSutunu - 6,
                                    child: Text(
                                      maisonDakikaMetni(dk),
                                      textAlign: TextAlign.end,
                                      style: maisonGovde(11, renk: r.soluk, yukseklik: 1.2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Container(height: 1, color: r.cizgi.withValues(alpha: 0.7))),
                                ],
                              ),
                            ),
                          ),
                        // Kayıtlar
                        for (final TakvimKaydi k in kayitlar)
                          if (sutunlar.indexWhere((_Sutun s) => s.id == k.ustaId) >= 0)
                            Positioned(
                              left: _saatSutunu +
                                  sutunlar.indexWhere((_Sutun s) => s.id == k.ustaId) * sutunGenisligi +
                                  4,
                              width: sutunGenisligi - 8,
                              top: (dakikaOf(k.baslangic) - bas) * _dakikaBoyu + 1,
                              height: math.max(24, (dakikaOf(k.bitis) - dakikaOf(k.baslangic)) * _dakikaBoyu - 2),
                              child: _KayitKutusu(kayit: k, onTap: () => _ayrinti(k)),
                            ),
                        // Şu an çizgisi
                        if (bugun && simdiDk >= bas && simdiDk <= son)
                          Positioned(
                            left: _saatSutunu - 4,
                            right: 0,
                            top: (simdiDk - bas) * _dakikaBoyu - 1,
                            height: 2,
                            child: IgnorePointer(child: ColoredBox(color: Theme.of(context).colorScheme.error)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- Hafta

  Widget _haftaGorunumu(MaisonRenkler r, List<TakvimKaydi> kayitlar) {
    final DateTime bas = _haftaBasi;
    return RefreshIndicator(
      color: r.vurgu,
      backgroundColor: r.kart,
      onRefresh: _kayitlariYukle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: <Widget>[
          for (int i = 0; i < 7; i++)
            Builder(
              builder: (BuildContext context) {
                final DateTime gun = DateTime(bas.year, bas.month, bas.day + i);
                final List<TakvimKaydi> gunun = kayitlar.where((TakvimKaydi k) => _ayniGun(k.baslangic, gun)).toList();
                final int randevu = gunun.where((TakvimKaydi k) => !k.blok && k.durum != 'iptal').length;
                final bool bugun = _ayniGun(gun, _bugun());
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            _gun = gun;
                            _gorunum = 0;
                            _kayitlar = null;
                          });
                          _kayitlariYukle();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: <Widget>[
                              Text(
                                '${maisonGun(gun)}, ${gun.day} ${maisonAy(gun)}',
                                style: maisonGovde(
                                  15,
                                  renk: bugun ? r.vurgu : r.yazi,
                                  kalinlik: FontWeight.w600,
                                  yukseklik: 1.3,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                randevu == 0 ? dl('Randevu yok', 'No bookings') : _randevuSayisi(randevu),
                                style: maisonGovde(12, renk: r.soluk),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: r.soluk),
                            ],
                          ),
                        ),
                      ),
                      for (final TakvimKaydi k in gunun)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TakvimSatiri(kayit: k, onTap: () => _ayrinti(k)),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Günlük görünümde bir kayıt kutusu.
class _KayitKutusu extends StatelessWidget {
  const _KayitKutusu({required this.kayit, required this.onTap});

  final TakvimKaydi kayit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final TakvimKaydi k = kayit;
    final bool sonuk = k.durum == 'iptal' || k.durum == 'gelmedi';
    final Color zemin = k.blok ? r.cizgi : (k.durum == 'tamamlandi' ? r.vurgu.withValues(alpha: 0.28) : r.vurguYumusak);
    final String baslik = k.blok
        ? ((k.ustaNotu ?? '').trim().isEmpty ? dl('Mola', 'Break') : k.ustaNotu!.trim())
        : (k.musteriAd ?? dl('Misafir', 'Guest'));
    final String alt = k.blok
        ? '${maisonSaat(k.baslangic)}–${maisonSaat(k.bitis)}'
        : '${maisonSaat(k.baslangic)} · ${k.hizmetler ?? (k.kaynak == 'dukkan' ? dl('Dükkân', 'Walk-in') : dl('Randevu', 'Booking'))}';
    return Opacity(
      opacity: sonuk ? 0.45 : 1,
      child: Material(
        color: zemin,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: k.blok ? r.soluk : r.vurgu, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(7, 4, 6, 4),
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          baslik,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: maisonGovde(
                            12,
                            renk: r.yazi,
                            kalinlik: FontWeight.w600,
                            yukseklik: 1.25,
                          ).copyWith(decoration: k.durum == 'iptal' ? TextDecoration.lineThrough : null),
                        ),
                      ),
                      if (k.durum == 'tamamlandi') Icon(Icons.check, size: 12, color: r.vurgu),
                      if (k.not != null && k.not!.trim().isNotEmpty && !k.blok)
                        Icon(Icons.sticky_note_2_outlined, size: 12, color: r.soluk),
                    ],
                  ),
                  Text(
                    alt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: maisonGovde(11, renk: r.soluk, yukseklik: 1.25),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Listelerde bir kayıt satırı (haftalık takvim, randevular, bugün).
class TakvimSatiri extends StatelessWidget {
  const TakvimSatiri({super.key, required this.kayit, required this.onTap, this.tarihli = false});

  final TakvimKaydi kayit;
  final VoidCallback onTap;

  /// Saatin üstünde gün de yazsın mı?
  final bool tarihli;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final TakvimKaydi k = kayit;
    final bool sonuk = !k.etkin;
    final String baslik = k.blok
        ? ((k.ustaNotu ?? '').trim().isEmpty ? dl('Mola', 'Break') : k.ustaNotu!.trim())
        : (k.musteriAd ?? dl('Misafir', 'Guest'));
    final String alt = k.blok ? k.ustaAd : '${k.hizmetler ?? dl('Randevu', 'Booking')} · ${k.ustaAd}';
    return Material(
      color: k.blok ? r.girdi : r.kart,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: r.cizgi),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (tarihli)
                      Text(
                        '${k.baslangic.day} ${maisonAy(k.baslangic).substring(0, 3)}',
                        style: maisonGovde(11, renk: r.soluk, yukseklik: 1.2),
                      ),
                    Text(
                      maisonSaat(k.baslangic),
                      style: maisonGovde(15, renk: sonuk ? r.soluk : r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
                    ),
                    Text(maisonSaat(k.bitis), style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3)),
                  ],
                ),
              ),
              Container(width: 1, height: 38, color: r.cizgi),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      baslik,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(15, renk: sonuk ? r.soluk : r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                    ),
                    Text(
                      alt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3),
                    ),
                  ],
                ),
              ),
              if (!k.blok && k.durum != 'onaylandi')
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    k.durumMetni,
                    style: maisonGovde(12, renk: k.durum == 'tamamlandi' ? r.vurgu : r.soluk, kalinlik: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "3 randevu" · "1 booking" · "3 bookings"
String _randevuSayisi(int n) => dl('$n randevu', n == 1 ? '1 booking' : '$n bookings');
