import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../isletme.dart';

/// Ustanın haftalık çalışma saatleri. Kaydedilince yeni saatlerle kapanır.
class CalismaSaatleriEkrani extends StatefulWidget {
  const CalismaSaatleriEkrani({super.key, required this.usta, required this.saatler});

  final ProUsta usta;
  final List<CalismaAraligi> saatler;

  @override
  State<CalismaSaatleriEkrani> createState() => _CalismaSaatleriEkraniState();
}

class _CalismaSaatleriEkraniState extends State<CalismaSaatleriEkrani> {
  late final Map<int, List<CalismaAraligi>> _gunler = <int, List<CalismaAraligi>>{
    for (int gun = 1; gun <= 7; gun++)
      gun: maisonAralikSirala(widget.saatler.where((CalismaAraligi a) => a.gun == gun)),
  };
  bool _degisti = false;
  bool _kaydediliyor = false;
  String? _uyari;

  static const int _varsayilanBaslangic = 9 * 60;
  static const int _varsayilanBitis = 19 * 60;

  void _guncelle(int gun, List<CalismaAraligi> yeni) {
    setState(() {
      _gunler[gun] = maisonAralikSirala(yeni);
      _degisti = true;
      _uyari = null;
    });
  }

  void _gunAcKapa(int gun, bool acik) {
    if (!acik) {
      _guncelle(gun, const <CalismaAraligi>[]);
      return;
    }
    // Açılan gün, önceki çalışılan günün saatlerini alır; yoksa 09:00–19:00.
    for (int onceki = gun - 1; onceki >= 1; onceki--) {
      final List<CalismaAraligi> o = _gunler[onceki] ?? const <CalismaAraligi>[];
      if (o.isNotEmpty) {
        _guncelle(gun, o.map((CalismaAraligi a) => a.copyWith(gun: gun)).toList());
        return;
      }
    }
    _guncelle(gun, <CalismaAraligi>[
      CalismaAraligi(gun: gun, baslangic: _varsayilanBaslangic, bitis: _varsayilanBitis),
    ]);
  }

  Future<void> _saatSec(int gun, int sira, {required bool bitisMi}) async {
    final List<CalismaAraligi> liste = List<CalismaAraligi>.of(_gunler[gun] ?? const <CalismaAraligi>[]);
    final CalismaAraligi a = liste[sira];
    final int? secilen = await maisonSaatSec(
      context,
      baslik: '${maisonGunAdi(gun)} · ${bitisMi ? dl('bitiş', 'end') : dl('başlangıç', 'start')}',
      secili: bitisMi ? a.bitis : a.baslangic,
      enAz: bitisMi ? a.baslangic + 15 : 0,
      enCok: bitisMi ? 1440 : a.bitis - 15,
    );
    if (secilen == null || !mounted) {
      return;
    }
    liste[sira] = bitisMi ? a.copyWith(bitis: secilen) : a.copyWith(baslangic: secilen);
    _guncelle(gun, liste);
  }

  int _yuvarla15(int dakika) => ((dakika / 15).round() * 15).clamp(0, 1440).toInt();

  /// Tek aralıklı güne öğle arası (ortada 1 saat), birden çok aralıklı güne yeni aralık ekler.
  void _aralikEkle(int gun) {
    final List<CalismaAraligi> liste = List<CalismaAraligi>.of(_gunler[gun] ?? const <CalismaAraligi>[]);
    if (liste.isEmpty) {
      return;
    }
    if (liste.length == 1 && liste.first.bitis - liste.first.baslangic >= 180) {
      final CalismaAraligi a = liste.first;
      // Gün 13:00–14:00'ü kapsıyorsa öğle arası o saattir; değilse ortadan 1 saat.
      final bool ogleKapsar = a.baslangic <= 12 * 60 && a.bitis >= 15 * 60;
      final int araBas = ogleKapsar ? 13 * 60 : _yuvarla15((a.baslangic + a.bitis) ~/ 2) - 30;
      _guncelle(gun, <CalismaAraligi>[
        a.copyWith(bitis: araBas),
        a.copyWith(baslangic: araBas + 60),
      ]);
      return;
    }
    final CalismaAraligi son = liste.last;
    if (liste.length >= 4 || son.bitis + 75 > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dl('Bu güne yeni aralık sığmıyor. Önce mevcut saatleri değiştir.', 'No room for another range on this day. Change the existing hours first.'))),
      );
      return;
    }
    liste.add(CalismaAraligi(gun: gun, baslangic: son.bitis + 60, bitis: (son.bitis + 180).clamp(0, 1440).toInt()));
    _guncelle(gun, liste);
  }

  void _aralikSil(int gun, int sira) {
    final List<CalismaAraligi> liste = List<CalismaAraligi>.of(_gunler[gun] ?? const <CalismaAraligi>[]);
    liste.removeAt(sira);
    _guncelle(gun, liste);
  }

  Future<void> _kopyala(int kaynak) async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Set<int>? hedefler = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => _GunSecici(kaynak: kaynak),
    );
    if (hedefler == null || hedefler.isEmpty || !mounted) {
      return;
    }
    final List<CalismaAraligi> kaynakSaatler = _gunler[kaynak] ?? const <CalismaAraligi>[];
    setState(() {
      for (final int gun in hedefler) {
        _gunler[gun] = kaynakSaatler.map((CalismaAraligi a) => a.copyWith(gun: gun)).toList();
      }
      _degisti = true;
      _uyari = null;
    });
  }

  void _hazirDuzen(Set<int> gunler, int baslangic, int bitis) {
    setState(() {
      for (int gun = 1; gun <= 7; gun++) {
        _gunler[gun] = gunler.contains(gun)
            ? <CalismaAraligi>[CalismaAraligi(gun: gun, baslangic: baslangic, bitis: bitis)]
            : <CalismaAraligi>[];
      }
      _degisti = true;
      _uyari = null;
    });
  }

  Future<void> _kaydet() async {
    for (int gun = 1; gun <= 7; gun++) {
      final String? sorun = maisonGunDenetle(_gunler[gun] ?? const <CalismaAraligi>[]);
      if (sorun != null) {
        setState(() => _uyari = sorun);
        return;
      }
    }
    final List<CalismaAraligi> tum = <CalismaAraligi>[
      for (int gun = 1; gun <= 7; gun++) ...?_gunler[gun],
    ];
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    setState(() {
      _kaydediliyor = true;
      _uyari = null;
    });
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      await i.rpc('usta_saatlerini_kaydet', params: <String, dynamic>{
        'p_usta': widget.usta.id,
        'p_saatler': tum.map((CalismaAraligi a) => a.json()).toList(),
      });
      _degisti = false;
      gezgin.pop(tum);
    } catch (hata) {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
          _uyari = maisonHataMetni(hata);
        });
      }
    }
  }

  Future<void> _cikisSor() async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool? cik = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: r.kart,
        title: Text(dl('Kaydedilmedi', 'Not saved'), style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
        content: Text(
          dl('Saatlerde yaptığın değişiklikler kaydedilmedi. Çıkarsan kaybolur.', 'Your changes to the hours are not saved. They will be lost if you leave.'),
          style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(dl('Kal', 'Stay'))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(dl('Kaydetmeden çık', 'Leave without saving'))),
        ],
      ),
    );
    if (cik == true && mounted) {
      _degisti = false;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? uyari = _uyari;
    return PopScope<Object?>(
      canPop: !_degisti,
      onPopInvokedWithResult: (bool cikti, Object? _) {
        if (!cikti && !_kaydediliyor) {
          _cikisSor();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: maisonSistemCubugu(MaisonTercih.proPaleti),
        child: Scaffold(
          backgroundColor: r.zemin,
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: <Widget>[
                      MaisonUstSatir(
                        sol: MaisonYuvarlakDugme(
                          ikon: Icons.arrow_back,
                          etiket: dl('Geri', 'Back'),
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        baslik: dl('Çalışma saatleri', 'Working hours'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        dl('${widget.usta.ad} · müşteriler yalnız bu saatlerde randevu alabilir.', '${widget.usta.ad} · customers can book only during these hours.'),
                        textAlign: TextAlign.center,
                        style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
                      ),
                      const SizedBox(height: 16),
                      MaisonUstBaslik(dl('HIZLI DÜZEN', 'QUICK SETUP')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          ActionChip(
                            label: Text(dl('Pzt–Cmt 09:00–20:00', 'Mon–Sat 09:00–20:00')),
                            onPressed: () => _hazirDuzen(<int>{1, 2, 3, 4, 5, 6}, 9 * 60, 20 * 60),
                          ),
                          ActionChip(
                            label: Text(dl('Hafta içi 09:00–19:00', 'Weekdays 09:00–19:00')),
                            onPressed: () => _hazirDuzen(<int>{1, 2, 3, 4, 5}, 9 * 60, 19 * 60),
                          ),
                          ActionChip(
                            label: Text(dl('Her gün 10:00–22:00', 'Every day 10:00–22:00')),
                            onPressed: () => _hazirDuzen(<int>{1, 2, 3, 4, 5, 6, 7}, 10 * 60, 22 * 60),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      for (int gun = 1; gun <= 7; gun++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _gunKarti(r, gun),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  decoration: BoxDecoration(
                    color: r.zemin,
                    border: Border(top: BorderSide(color: r.cizgi)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (uyari != null) ...<Widget>[
                        MaisonHataKutusu(uyari),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _kaydediliyor ? null : _kaydet,
                          child: Text(_kaydediliyor ? dl('Kaydediliyor…', 'Saving…') : dl('Kaydet', 'Save')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gunKarti(MaisonRenkler r, int gun) {
    final List<CalismaAraligi> araliklar = _gunler[gun] ?? const <CalismaAraligi>[];
    final bool acik = araliklar.isNotEmpty;
    final bool tekAralikUzun = araliklar.length == 1 && araliklar.first.bitis - araliklar.first.baslangic >= 180;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      decoration: BoxDecoration(
        color: acik ? r.kart : r.zemin,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: r.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  maisonGunAdi(gun),
                  style: maisonGovde(15, renk: acik ? r.yazi : r.soluk, kalinlik: FontWeight.w600, yukseklik: 1.3),
                ),
              ),
              Text(
                acik ? dl('Çalışıyor', 'Working') : dl('Kapalı', 'Closed'),
                style: maisonGovde(12, renk: r.soluk, kalinlik: FontWeight.w500),
              ),
              const SizedBox(width: 6),
              MaisonAnahtar(
                deger: acik,
                etiket: dl('${maisonGunAdi(gun)} çalışıyor', '${maisonGunAdi(gun)} working'),
                onChanged: (bool yeni) => _gunAcKapa(gun, yeni),
              ),
            ],
          ),
          if (acik) ...<Widget>[
            const SizedBox(height: 4),
            for (int sira = 0; sira < araliklar.length; sira++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    _SaatKutusu(
                      metin: maisonDakikaMetni(araliklar[sira].baslangic),
                      etiket: dl('${maisonGunAdi(gun)} başlangıç', '${maisonGunAdi(gun)} start'),
                      onTap: () => _saatSec(gun, sira, bitisMi: false),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: maisonGovde(16, renk: r.soluk)),
                    ),
                    _SaatKutusu(
                      metin: maisonDakikaMetni(araliklar[sira].bitis),
                      etiket: dl('${maisonGunAdi(gun)} bitiş', '${maisonGunAdi(gun)} end'),
                      onTap: () => _saatSec(gun, sira, bitisMi: true),
                    ),
                    const Spacer(),
                    if (araliklar.length > 1)
                      IconButton(
                        tooltip: dl('Aralığı sil', 'Delete range'),
                        onPressed: () => _aralikSil(gun, sira),
                        icon: Icon(Icons.close, size: 20, color: r.soluk),
                      ),
                  ],
                ),
              ),
            Wrap(
              spacing: 4,
              children: <Widget>[
                if (araliklar.length < 4)
                  TextButton.icon(
                    onPressed: () => _aralikEkle(gun),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tekAralikUzun ? dl('Öğle arası ekle', 'Add lunch break') : dl('Aralık ekle', 'Add range')),
                  ),
                TextButton.icon(
                  onPressed: () => _kopyala(gun),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: Text(dl('Diğer günlere kopyala', 'Copy to other days')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SaatKutusu extends StatelessWidget {
  const _SaatKutusu({required this.metin, required this.etiket, required this.onTap});

  final String metin;
  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Semantics(
      button: true,
      label: '$etiket $metin',
      excludeSemantics: true,
      child: Material(
        color: r.girdi,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 84, minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: r.cizgi),
            ),
            child: Text(
              metin,
              style: maisonGovde(17, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Saatlerin kopyalanacağı günleri seçtirir.
class _GunSecici extends StatefulWidget {
  const _GunSecici({required this.kaynak});

  final int kaynak;

  @override
  State<_GunSecici> createState() => _GunSeciciState();
}

class _GunSeciciState extends State<_GunSecici> {
  final Set<int> _secili = <int>{};

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final List<int> gunler = <int>[for (int g = 1; g <= 7; g++) if (g != widget.kaynak) g];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              dl('${maisonGunAdi(widget.kaynak)} saatlerini kopyala', 'Copy ${maisonGunAdi(widget.kaynak)} hours'),
              style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ActionChip(
                  label: Text(dl('Hafta içi', 'Weekdays')),
                  onPressed: () => setState(() {
                    _secili
                      ..clear()
                      ..addAll(gunler.where((int g) => g <= 5));
                  }),
                ),
                ActionChip(
                  label: Text(dl('Hepsi', 'All')),
                  onPressed: () => setState(() {
                    _secili
                      ..clear()
                      ..addAll(gunler);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final int g in gunler)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _secili.contains(g),
                title: Text(maisonGunAdi(g), style: maisonGovde(15, renk: r.yazi)),
                onChanged: (bool? yeni) => setState(() {
                  if (yeni ?? false) {
                    _secili.add(g);
                  } else {
                    _secili.remove(g);
                  }
                }),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _secili.isEmpty ? null : () => Navigator.of(context).pop(Set<int>.of(_secili)),
                child: Text(dl('Kopyala', 'Copy')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
