import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../veri.dart';

/// Randevu: 1) hizmet ve usta, 2) gün ve saat, 3) onay. Salonun vitrin temasıyla açılır.
class RandevuAkisi extends StatefulWidget {
  const RandevuAkisi({super.key, required this.salon});

  final VitrinSalonu salon;

  @override
  State<RandevuAkisi> createState() => _RandevuAkisiState();
}

class _RandevuAkisiState extends State<RandevuAkisi> {
  /// Boş saatler bugünden itibaren bu kadar gün için aranır.
  static const int _gunSayisi = 14;

  VitrinVerisi? _veri;
  Object? _yuklemeHatasi;

  /// 0: hizmet ve usta, 1: gün ve saat, 2: onay
  int _adim = 0;

  final Set<String> _secili = <String>{};

  /// Seçilen usta; null = "Fark etmez".
  String? _usta;

  List<BosSaat>? _saatler;
  Object? _saatHatasi;
  bool _saatYukleniyor = false;
  int _sorgu = 0;

  DateTime? _gun;
  DateTime? _saat;
  final TextEditingController _not = TextEditingController();
  bool _gonderiliyor = false;
  String? _uyari;

  String? _atananUsta;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_veri == null && _yuklemeHatasi == null) {
      _yukle();
    }
  }

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final SupabaseClient i = await OturumKapsami.oku(context).istemciGerekli();
      final VitrinVerisi v = await VitrinVerisi.yukle(i, _salon.id);
      if (mounted) {
        setState(() {
          _veri = v;
          _yuklemeHatasi = null;
        });
      }
    } catch (hata) {
      if (mounted) {
        setState(() => _yuklemeHatasi = hata);
      }
    }
  }

  // ---------------------------------------------------------------- Hesaplar

  /// Sunucudan gelen güncel salon bilgisi (iptal süresi, adres); gelene kadar vitrindeki.
  VitrinSalonu get _salon => _veri?.salon ?? widget.salon;

  List<VitrinHizmeti> get _hizmetler => _veri?.hizmetler ?? const <VitrinHizmeti>[];

  List<VitrinHizmeti> get _secilenler =>
      _hizmetler.where((VitrinHizmeti h) => _secili.contains(h.id)).toList();

  int get _sure => _secilenler.fold<int>(0, (int t, VitrinHizmeti h) => t + h.sureDk);

  double get _fiyat => _secilenler.fold<double>(0, (double t, VitrinHizmeti h) => t + h.fiyat);

  VitrinUstasi? _ustaBul(String? id) {
    for (final VitrinUstasi u in _veri?.ekip ?? const <VitrinUstasi>[]) {
      if (u.id == id) {
        return u;
      }
    }
    return null;
  }

  /// Seçilen ustaya (ya da herkese) göre boş başlangıçlar; aynı saat bir kez.
  List<DateTime> get _uygunSaatler {
    final List<BosSaat> tum = _saatler ?? const <BosSaat>[];
    final Set<DateTime> saatler = <DateTime>{
      for (final BosSaat s in tum)
        if (_usta == null || s.ustaId == _usta) s.baslangic,
    };
    return saatler.toList()..sort();
  }

  DateTime? _enErken(String? usta) {
    DateTime? en;
    for (final BosSaat s in _saatler ?? const <BosSaat>[]) {
      if ((usta == null || s.ustaId == usta) && (en == null || s.baslangic.isBefore(en))) {
        en = s.baslangic;
      }
    }
    return en;
  }

  static DateTime _gunu(DateTime t) => DateTime(t.year, t.month, t.day);

  static bool _ayniGun(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _kisaZaman(DateTime t) {
    final DateTime bugun = _gunu(DateTime.now());
    final int fark = _gunu(t).difference(bugun).inDays;
    final String gun = fark == 0
        ? 'Bugün'
        : fark == 1
            ? 'Yarın'
            : '${maisonGunKisa(t.weekday)} ${t.day} ${maisonAy(t)}';
    return '$gun · ${maisonSaat(t)}';
  }

  // ---------------------------------------------------------------- İşlemler

  Future<void> _saatleriYukle() async {
    final int sorgu = ++_sorgu;
    if (_secili.isEmpty) {
      setState(() {
        _saatler = null;
        _saatHatasi = null;
        _saatYukleniyor = false;
      });
      return;
    }
    setState(() {
      _saatYukleniyor = true;
      _saatHatasi = null;
    });
    try {
      final List<BosSaat> saatler = await Veri.of(context).bosSaatler(
        salonId: _salon.id,
        bas: DateTime.now(),
        gunSayisi: _gunSayisi,
        hizmetler: _secili.toList(),
      );
      if (!mounted || sorgu != _sorgu) {
        return;
      }
      setState(() {
        _saatler = saatler;
        _saatYukleniyor = false;
        final String? usta = _usta;
        if (usta != null && !saatler.any((BosSaat s) => s.ustaId == usta)) {
          _usta = null;
        }
      });
    } catch (hata) {
      if (mounted && sorgu == _sorgu) {
        setState(() {
          _saatHatasi = hata;
          _saatYukleniyor = false;
        });
      }
    }
  }

  void _hizmetSec(VitrinHizmeti h) {
    setState(() {
      if (!_secili.remove(h.id)) {
        _secili.add(h.id);
      }
      _saat = null;
      _uyari = null;
    });
    _saatleriYukle();
  }

  void _devam() {
    final List<DateTime> saatler = _uygunSaatler;
    if (saatler.isEmpty) {
      return;
    }
    final DateTime? gun = _gun;
    setState(() {
      _adim = 1;
      _uyari = null;
      if (gun == null || !saatler.any((DateTime s) => _ayniGun(s, gun))) {
        _gun = _gunu(saatler.first);
      }
      final DateTime? saat = _saat;
      if (saat != null && !saatler.contains(saat)) {
        _saat = null;
      }
    });
  }

  void _geri() {
    if (_adim == 1) {
      setState(() {
        _adim = 0;
        _uyari = null;
      });
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _onayla() async {
    final DateTime? saat = _saat;
    if (saat == null || _gonderiliyor) {
      return;
    }
    final Veri veri = Veri.of(context);
    setState(() {
      _gonderiliyor = true;
      _uyari = null;
    });
    try {
      final String not = _not.text.trim();
      final String id = await veri.randevuAl(
        salonId: _salon.id,
        baslangic: saat,
        hizmetler: _secili.toList(),
        ustaId: _usta,
        not: not.isEmpty ? null : not,
      );
      String? atanan = _usta;
      if (atanan == null) {
        try {
          atanan = await veri.randevununUstasi(id);
        } catch (_) {
          atanan = null;
        }
      }
      if (mounted) {
        setState(() {
          _atananUsta = atanan;
          _adim = 2;
          _gonderiliyor = false;
        });
      }
      // Hatırlatmalar için bildirim izni (yalnız ilk seferde sorulur; sonra sistem hatırlar).
      if (await MaisonBildirim.hatirlatmaAcik()) {
        await MaisonBildirim.izinIste();
      }
    } catch (hata) {
      if (!mounted) {
        return;
      }
      setState(() {
        _gonderiliyor = false;
        _uyari = maisonHataMetni(hata);
        _saat = null;
      });
      // Saat az önce dolmuş olabilir: liste yenilenir.
      await _saatleriYukle();
    }
  }

  Future<void> _yolTarifi() async {
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    if (!await maisonYolTarifiAc(_salon)) {
      mesaj.showSnackBar(const SnackBar(content: Text('Harita açılamadı.')));
    }
  }

  // ---------------------------------------------------------------- Ekran

  @override
  Widget build(BuildContext context) {
    return MaisonVitrinTemasi(
      ayar: _salon.ayar,
      child: Builder(builder: _icerik),
    );
  }

  Widget _icerik(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final VitrinVerisi? veri = _veri;
    final Object? hata = _yuklemeHatasi;
    final Widget govde;
    if (veri == null) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: hata != null
              ? MaisonHataKutusu(
                  maisonHataMetni(hata),
                  tekrar: () {
                    setState(() => _yuklemeHatasi = null);
                    _yukle();
                  },
                )
              : const MaisonYukleniyor(),
        ),
      );
    } else if (_adim == 2) {
      govde = _onayEkrani(context, r);
    } else {
      govde = Column(
        children: <Widget>[
          _ustSerit(r),
          Expanded(child: _adim == 0 ? _hizmetVeUsta(context, r, veri) : _gunVeSaat(context, r)),
          _altCubuk(context, r),
        ],
      );
    }
    return PopScope<Object?>(
      canPop: _adim != 1,
      onPopInvokedWithResult: (bool cikti, Object? _) {
        if (!cikti && _adim == 1) {
          _geri();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: maisonSistemCubugu(_salon.ayar.palet),
        child: Scaffold(
          backgroundColor: r.zemin,
          body: SafeArea(child: govde),
        ),
      ),
    );
  }

  Widget _ustSerit(MaisonRenkler r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MaisonUstSatir(
            sol: MaisonYuvarlakDugme(
              ikon: _adim == 0 ? Icons.close : Icons.arrow_back,
              etiket: _adim == 0 ? 'Kapat' : 'Geri',
              onTap: _geri,
            ),
            baslik: 'Randevu',
          ),
          const SizedBox(height: 6),
          Text(
            _salon.ad,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= _adim ? r.vurgu : r.cizgi,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          MaisonUstBaslik(_adim == 0 ? '1 / 3 · HİZMET VE USTA' : '2 / 3 · GÜN VE SAAT'),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 1. Hizmet ve usta

  Widget _hizmetVeUsta(BuildContext context, MaisonRenkler r, VitrinVerisi veri) {
    final List<VitrinHizmeti> hizmetler = veri.hizmetler;
    if (hizmetler.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const <Widget>[
          MaisonBosDurum(
            ikon: Icons.content_cut,
            baslik: 'Hizmet menüsü henüz yok',
            aciklama: 'Salon hizmetlerini ekleyince buradan randevu alabileceksin. '
                'Şimdilik salonu arayarak randevu alabilirsin.',
          ),
        ],
      );
    }
    final Set<HizmetKategorisi> kategoriler = hizmetler.map((VitrinHizmeti h) => h.kategori).toSet();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: <Widget>[
        Text('Hizmet seç', style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1)),
        const SizedBox(height: 4),
        Text(
          'Birden çok hizmet seçebilirsin; süreleri toplanır.',
          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
        ),
        for (final HizmetKategorisi k in HizmetKategorisi.values)
          if (kategoriler.contains(k)) ...<Widget>[
            if (kategoriler.length > 1) ...<Widget>[
              const SizedBox(height: 18),
              MaisonUstBaslik(maisonBuyukHarf(k.ad)),
            ],
            const SizedBox(height: 8),
            for (final VitrinHizmeti h in hizmetler.where((VitrinHizmeti h) => h.kategori == k))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HizmetSecimi(
                  hizmet: h,
                  secili: _secili.contains(h.id),
                  paraBirimi: _salon.paraBirimi,
                  onTap: () => _hizmetSec(h),
                ),
              ),
          ],
        const SizedBox(height: 18),
        Text('Usta seç', style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1)),
        const SizedBox(height: 8),
        ..._ustaSecimi(r, veri),
      ],
    );
  }

  List<Widget> _ustaSecimi(MaisonRenkler r, VitrinVerisi veri) {
    if (_secili.isEmpty) {
      return <Widget>[
        Text(
          'Önce hizmet seç; hangi ustanın ne zaman boş olduğunu gösterelim.',
          style: maisonGovde(14, renk: r.soluk, yukseklik: 1.45),
        ),
      ];
    }
    final Object? hata = _saatHatasi;
    if (hata != null) {
      return <Widget>[MaisonHataKutusu(maisonHataMetni(hata), tekrar: _saatleriYukle)];
    }
    if (_saatler == null) {
      return const <Widget>[MaisonYukleniyor()];
    }
    final DateTime? herkes = _enErken(null);
    return <Widget>[
      if (_saatYukleniyor)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LinearProgressIndicator(
            minHeight: 2,
            color: r.vurgu,
            backgroundColor: r.cizgi,
          ),
        ),
      if (herkes == null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Seçtiğin hizmetler için önümüzdeki $_gunSayisi günde boş saat yok. '
            'Farklı bir hizmet seç ya da salonu ara.',
            style: maisonGovde(14, renk: Theme.of(context).colorScheme.error, yukseklik: 1.45),
          ),
        ),
      _UstaSecimi(
        baslik: 'Fark etmez',
        alt: herkes == null ? 'Boş saat yok' : 'En erken boş usta · ${_kisaZaman(herkes)}',
        secili: _usta == null,
        etkin: herkes != null,
        onTap: () => setState(() => _usta = null),
      ),
      for (final VitrinUstasi u in veri.ekip)
        Builder(
          builder: (BuildContext context) {
            final DateTime? en = _enErken(u.id);
            final String? unvan = u.uzmanlik.isNotEmpty ? u.uzmanlik.first : u.unvan;
            return _UstaSecimi(
              usta: u,
              baslik: u.ad,
              alt: en == null
                  ? 'Bu hizmetler için boş saati yok'
                  : '${unvan == null || unvan.isEmpty ? '' : '$unvan · '}En erken ${_kisaZaman(en)}',
              secili: _usta == u.id,
              etkin: en != null,
              onTap: () => setState(() => _usta = u.id),
            );
          },
        ),
    ];
  }

  // ---------------------------------------------------------------- 2. Gün ve saat

  Widget _gunVeSaat(BuildContext context, MaisonRenkler r) {
    final List<DateTime> saatler = _uygunSaatler;
    final DateTime bugun = _gunu(DateTime.now());
    final List<DateTime> gunler = <DateTime>[
      for (int i = 0; i < _gunSayisi; i++) DateTime(bugun.year, bugun.month, bugun.day + i),
    ];
    final DateTime gun = _gun ?? (saatler.isEmpty ? bugun : _gunu(saatler.first));
    final List<DateTime> gununSaatleri = saatler.where((DateTime s) => _ayniGun(s, gun)).toList();
    final List<(String, List<DateTime>)> gruplar = <(String, List<DateTime>)>[
      ('Sabah', gununSaatleri.where((DateTime s) => s.hour < 12).toList()),
      ('Öğleden sonra', gununSaatleri.where((DateTime s) => s.hour >= 12 && s.hour < 17).toList()),
      ('Akşam', gununSaatleri.where((DateTime s) => s.hour >= 17).toList()),
    ];
    final DateTime? enErken = saatler.isEmpty ? null : saatler.first;
    final String? uyari = _uyari;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Gün ve saat',
                  style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
                ),
              ),
              Text('${maisonAy(gun)} ${gun.year}', style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: gunler.length,
            separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) {
              final DateTime g = gunler[i];
              final int adet = saatler.where((DateTime s) => _ayniGun(s, g)).length;
              return _GunKutusu(
                gun: g,
                secili: _ayniGun(g, gun),
                adet: adet,
                onTap: adet == 0
                    ? null
                    : () => setState(() {
                          _gun = g;
                          _saat = null;
                          _uyari = null;
                        }),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (enErken != null)
                Text(
                  'En erken: ${maisonGun(enErken)} ${enErken.day} ${maisonAy(enErken)} · ${maisonSaat(enErken)}',
                  style: maisonGovde(13, renk: r.vurgu, kalinlik: FontWeight.w500, yukseklik: 1.4),
                ),
              if (uyari != null) ...<Widget>[
                const SizedBox(height: 12),
                MaisonHataKutusu(uyari),
              ],
              if (_saatYukleniyor) ...<Widget>[
                const SizedBox(height: 12),
                LinearProgressIndicator(minHeight: 2, color: r.vurgu, backgroundColor: r.cizgi),
              ],
              if (gununSaatleri.isEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  'Bu gün için boş saat kalmadı. Başka bir gün seç.',
                  style: maisonGovde(14, renk: r.soluk, yukseklik: 1.45),
                ),
              ],
              for (final (String ad, List<DateTime> liste) in gruplar)
                if (liste.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  MaisonUstBaslik(maisonBuyukHarf(ad)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final DateTime s in liste)
                        _SaatKutusu(
                          saat: s,
                          secili: _saat == s,
                          onTap: () => setState(() {
                            _saat = s;
                            _uyari = null;
                          }),
                        ),
                    ],
                  ),
                ],
              const SizedBox(height: 24),
              MaisonAlan(
                etiket: 'USTA İÇİN NOT (İSTEĞE BAĞLI)',
                kontrol: _not,
                ipucu: 'Ör. Yanlar kısa, üstü makasla',
                enFazla: 500,
                buyukHarf: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Alt çubuk

  Widget _altCubuk(BuildContext context, MaisonRenkler r) {
    final List<VitrinHizmeti> secilenler = _secilenler;
    final String ustaMetni = _usta == null ? 'Fark etmez' : 'Usta ${_ustaBul(_usta)?.ad ?? ''}';
    final String ust;
    final String alt;
    final VoidCallback? eylem;
    final String dugme;
    if (_adim == 0) {
      ust = secilenler.isEmpty ? 'Hizmet seçilmedi' : secilenler.map((VitrinHizmeti h) => h.ad).join(', ');
      alt = secilenler.isEmpty ? 'En az bir hizmet seç' : '${maisonSure(_sure)} · $ustaMetni';
      eylem = secilenler.isNotEmpty && !_saatYukleniyor && _uygunSaatler.isNotEmpty ? _devam : null;
      dugme = 'Devam';
    } else {
      final DateTime? saat = _saat;
      ust = saat == null
          ? 'Saat seçilmedi'
          : '${maisonGun(saat)}, ${saat.day} ${maisonAy(saat)} · ${maisonSaat(saat)}';
      alt = '$ustaMetni · ${maisonSure(_sure)}';
      eylem = saat != null && !_gonderiliyor ? _onayla : null;
      dugme = _gonderiliyor ? 'Alınıyor…' : 'Randevuyu onayla';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: r.kart,
        border: Border(top: BorderSide(color: r.cizgi)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ust,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                    ),
                    Text(
                      alt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(13, renk: r.soluk, yukseklik: 1.35),
                    ),
                  ],
                ),
              ),
              if (secilenler.isNotEmpty) ...<Widget>[
                const SizedBox(width: 12),
                Text(
                  maisonPara(_fiyat, _salon.paraBirimi),
                  style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 54, child: FilledButton(onPressed: eylem, child: Text(dugme))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 3. Onay

  Widget _onayEkrani(BuildContext context, MaisonRenkler r) {
    final DateTime? saat = _saat;
    final VitrinUstasi? usta = _ustaBul(_atananUsta);
    final VitrinSalonu s = _salon;
    final int iptalDk = s.ucretsizIptalDk;
    final String iptalMetni = iptalDk <= 0
        ? 'Randevunu başlangıcına kadar ücretsiz iptal edebilirsin.'
        : 'Ücretsiz iptal: randevudan ${iptalDk % 60 == 0 ? '${iptalDk ~/ 60} saat' : '$iptalDk dakika'} öncesine kadar.';
    final List<(String, String)> satirlar = <(String, String)>[
      ('Salon', s.yer.isEmpty ? s.ad : '${s.ad}, ${s.yer}'),
      if (saat != null) ('Tarih', '${maisonGun(saat)}, ${saat.day} ${maisonAy(saat)} · ${maisonSaat(saat)}'),
      ('Hizmet', '${_secilenler.map((VitrinHizmeti h) => h.ad).join(', ')} · ${maisonSure(_sure)}'),
      if (usta != null) ('Usta', usta.ad),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: <Widget>[
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: r.vurguYumusak, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 36, color: r.vurgu),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Randevun hazır',
          textAlign: TextAlign.center,
          style: maisonBaslik(38, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.05),
        ),
        const SizedBox(height: 6),
        Text(
          usta != null ? 'Usta ${usta.ad} seni bekliyor.' : 'Salon seni bekliyor.',
          textAlign: TextAlign.center,
          style: maisonGovde(15, renk: r.soluk, yukseklik: 1.4),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          decoration: BoxDecoration(
            color: r.kart,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: r.cizgi),
          ),
          child: Column(
            children: <Widget>[
              for (final (String etiket, String deger) in satirlar)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 72,
                        child: Text(etiket, style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4)),
                      ),
                      Expanded(
                        child: Text(
                          deger,
                          textAlign: TextAlign.end,
                          style: maisonGovde(14, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Toplam', style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3)),
                          Text('salonda ödenir', style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3)),
                        ],
                      ),
                    ),
                    Text(
                      maisonPara(_fiyat, s.paraBirimi),
                      style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Randevudan 24 saat ve 2 saat önce telefonuna hatırlatma gelir. $iptalMetni '
          'İptal etmen gerekirse Randevularım\'dan yapabilirsin.',
          textAlign: TextAlign.center,
          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _yolTarifi,
            icon: const Icon(Icons.place_outlined, size: 18),
            label: const Text('Yol tarifi'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: () => Navigator.of(context).popUntil((Route<dynamic> rota) => rota.isFirst),
            child: const Text('Ana sayfaya dön'),
          ),
        ),
      ],
    );
  }
}

class _HizmetSecimi extends StatelessWidget {
  const _HizmetSecimi({
    required this.hizmet,
    required this.secili,
    required this.paraBirimi,
    required this.onTap,
  });

  final VitrinHizmeti hizmet;
  final bool secili;
  final String paraBirimi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? aciklama = hizmet.aciklama;
    return Semantics(
      button: true,
      selected: secili,
      child: Material(
        color: secili ? r.vurguYumusak : r.kart,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: secili ? r.vurgu : r.cizgi, width: secili ? 1.5 : 1),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  secili ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: secili ? r.vurgu : r.soluk,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hizmet.ad,
                        style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                      ),
                      Text(
                        aciklama != null && aciklama.trim().isNotEmpty
                            ? '${maisonSure(hizmet.sureDk)} · ${aciklama.trim()}'
                            : maisonSure(hizmet.sureDk),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: maisonGovde(13, renk: r.soluk, yukseklik: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  maisonPara(hizmet.fiyat, paraBirimi),
                  style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UstaSecimi extends StatelessWidget {
  const _UstaSecimi({
    required this.baslik,
    required this.alt,
    required this.secili,
    required this.etkin,
    required this.onTap,
    this.usta,
  });

  /// null = "Fark etmez"
  final VitrinUstasi? usta;
  final String baslik;
  final String alt;
  final bool secili;
  final bool etkin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final VitrinUstasi? u = usta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        selected: secili,
        enabled: etkin,
        child: Opacity(
          opacity: etkin ? 1 : 0.5,
          child: Material(
            color: secili ? r.vurguYumusak : r.kart,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: etkin ? onTap : null,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: secili ? r.vurgu : r.cizgi, width: secili ? 1.5 : 1),
                ),
                child: Row(
                  children: <Widget>[
                    if (u == null)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: r.zemin, shape: BoxShape.circle),
                        child: Icon(Icons.groups_outlined, color: r.vurgu, size: 22),
                      )
                    else
                      MaisonAvatar(basHarfler: u.basHarfler, boyut: 48, fotoUrl: u.fotoUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            baslik,
                            style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                          ),
                          Text(
                            alt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: maisonGovde(12, renk: r.soluk, yukseklik: 1.35),
                          ),
                        ],
                      ),
                    ),
                    if (secili) Icon(Icons.check_circle, color: r.vurgu, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GunKutusu extends StatelessWidget {
  const _GunKutusu({required this.gun, required this.secili, required this.adet, required this.onTap});

  final DateTime gun;
  final bool secili;
  final int adet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool bos = adet == 0;
    final Color yazi = secili ? r.vurguUstu : (bos ? r.soluk.withValues(alpha: 0.6) : r.yazi);
    return Semantics(
      button: true,
      selected: secili,
      enabled: !bos,
      label: '${maisonGun(gun)} ${gun.day} ${maisonAy(gun)}${bos ? ', boş saat yok' : ', $adet boş saat'}',
      excludeSemantics: true,
      child: Material(
        color: secili ? r.vurgu : r.kart,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: secili ? r.vurgu : r.cizgi),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(maisonGunKisa(gun.weekday), style: maisonGovde(12, renk: yazi, kalinlik: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${gun.day}',
                  style: maisonBaslik(24, renk: yazi, kalinlik: FontWeight.w600, yukseklik: 1.0),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bos ? Colors.transparent : (secili ? r.vurguUstu : r.vurgu),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaatKutusu extends StatelessWidget {
  const _SaatKutusu({required this.saat, required this.secili, required this.onTap});

  final DateTime saat;
  final bool secili;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Semantics(
      button: true,
      selected: secili,
      child: Material(
        color: secili ? r.vurgu : r.kart,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 76,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: secili ? r.vurgu : r.cizgi),
            ),
            child: Text(
              maisonSaat(saat),
              style: maisonGovde(15, renk: secili ? r.vurguUstu : r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}
