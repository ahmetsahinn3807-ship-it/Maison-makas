import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../isletme.dart';
import '../salon.dart';

/// Hizmet menüsü: kategoriye göre liste, ekle/düzenle, sürükleyip sırala, hazır menüden ekle.
class HizmetlerEkrani extends StatefulWidget {
  const HizmetlerEkrani({super.key, required this.salon});

  final ProSalon salon;

  @override
  State<HizmetlerEkrani> createState() => _HizmetlerEkraniState();
}

class _HizmetlerEkraniState extends State<HizmetlerEkrani> {
  List<ProHizmet>? _hizmetler;
  Object? _hata;
  bool _isleniyor = false;

  bool get _sahibim => widget.salon.sahibim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hizmetler == null && _hata == null) {
      _yukle();
    }
  }

  Future<void> _yukle() async {
    try {
      final SupabaseClient i = await OturumKapsami.oku(context).istemciGerekli();
      final List<Map<String, dynamic>> satirlar = await i
          .from('hizmetler')
          .select(ProHizmet.sutunlar)
          .eq('salon_id', widget.salon.id)
          .order('sira', ascending: true)
          .order('ad', ascending: true);
      if (mounted) {
        setState(() {
          _hizmetler = satirlar.map(ProHizmet.json).toList();
          _hata = null;
        });
      }
    } catch (hata) {
      if (mounted) {
        setState(() => _hata = hata);
      }
    }
  }

  void _tekrarDene() {
    setState(() {
      _hata = null;
      _hizmetler = null;
    });
    _yukle();
  }

  List<ProHizmet> _grup(List<ProHizmet> tum, HizmetKategorisi k) =>
      tum.where((ProHizmet h) => h.kategori == k).toList();

  /// Kategori sırasına göre düz liste (müşterinin vitrinde gördüğü sıra).
  List<ProHizmet> _duzListe(List<ProHizmet> tum) => <ProHizmet>[
        for (final HizmetKategorisi k in HizmetKategorisi.values) ..._grup(tum, k),
      ];

  Future<void> _calistir(Future<void> Function(SupabaseClient i) gorev) async {
    if (_isleniyor) {
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    setState(() => _isleniyor = true);
    try {
      await gorev(await oturum.istemciGerekli());
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    } finally {
      if (mounted) {
        setState(() => _isleniyor = false);
      }
    }
  }

  Future<void> _sirala(HizmetKategorisi k, int eski, int yeni) async {
    final List<ProHizmet>? tum = _hizmetler;
    if (tum == null || !_sahibim || _isleniyor) {
      return;
    }
    final List<ProHizmet> grup = _grup(tum, k);
    // onReorderItem: yeni, taşınan öğe çıkarıldıktan sonraki konumdur.
    final int hedef = yeni;
    if (hedef == eski) {
      return;
    }
    final ProHizmet tasinan = grup.removeAt(eski);
    grup.insert(hedef, tasinan);
    final List<ProHizmet> sirali = <ProHizmet>[
      for (final HizmetKategorisi g in HizmetKategorisi.values) ...(g == k ? grup : _grup(tum, g)),
    ];
    final List<ProHizmet> yeniListe = <ProHizmet>[
      for (int i = 0; i < sirali.length; i++) sirali[i].copyWith(sira: i + 1),
    ];
    setState(() => _hizmetler = yeniListe);
    await _calistir((SupabaseClient i) async {
      try {
        await i.rpc('hizmet_sirala', params: <String, dynamic>{
          'p_salon': widget.salon.id,
          'p_hizmetler': yeniListe.map((ProHizmet h) => h.id).toList(),
        });
      } catch (_) {
        if (mounted) {
          setState(() => _hizmetler = tum);
        }
        rethrow;
      }
    });
  }

  Future<void> _ekleDuzenle([ProHizmet? hizmet]) async {
    if (!_sahibim || _isleniyor) {
      return;
    }
    final MaisonRenkler r = MaisonRenkler.of(context);
    final _HizmetKarari? karar = await showModalBottomSheet<_HizmetKarari>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => _HizmetFormu(hizmet: hizmet),
    );
    if (karar == null || !mounted) {
      return;
    }
    if (karar.sil && hizmet != null) {
      await _sil(hizmet);
      return;
    }
    final HizmetTaslagi? taslak = karar.taslak;
    if (taslak == null) {
      return;
    }
    await _calistir((SupabaseClient i) async {
      if (hizmet == null) {
        final List<ProHizmet> tum = _hizmetler ?? <ProHizmet>[];
        final int sira = tum.fold<int>(0, (int enBuyuk, ProHizmet h) => h.sira > enBuyuk ? h.sira : enBuyuk) + 1;
        final Map<String, dynamic> satir = await i
            .from('hizmetler')
            .insert(<String, dynamic>{...taslak.kayit(), 'salon_id': widget.salon.id, 'sira': sira})
            .select(ProHizmet.sutunlar)
            .single();
        if (mounted) {
          setState(() => _hizmetler = <ProHizmet>[...tum, ProHizmet.json(satir)]);
        }
      } else {
        final Map<String, dynamic> satir = await i
            .from('hizmetler')
            .update(taslak.kayit())
            .eq('id', hizmet.id)
            .select(ProHizmet.sutunlar)
            .single();
        final ProHizmet yeni = ProHizmet.json(satir);
        if (mounted) {
          setState(() {
            _hizmetler = (_hizmetler ?? <ProHizmet>[])
                .map((ProHizmet h) => h.id == yeni.id ? yeni : h)
                .toList();
          });
        }
      }
    });
  }

  Future<void> _sil(ProHizmet hizmet) async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool? eminim = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: r.kart,
        title: Text('${hizmet.ad} silinsin mi?', style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
        content: Text(
          'Hizmet menüden kalkar. Geçmiş randevulardaki kaydı olduğu gibi kalır. '
          'Bir süreliğine kaldırmak istiyorsan "Müşterilere görünsün"ü kapatman yeterli.',
          style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Sil', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (eminim != true || !mounted) {
      return;
    }
    await _calistir((SupabaseClient i) async {
      await i.from('hizmetler').delete().eq('id', hizmet.id);
      if (mounted) {
        setState(() {
          _hizmetler = (_hizmetler ?? <ProHizmet>[]).where((ProHizmet h) => h.id != hizmet.id).toList();
        });
      }
    });
  }

  Future<void> _hazirMenu() async {
    if (!_sahibim || _isleniyor) {
      return;
    }
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Set<String> mevcut = (_hizmetler ?? <ProHizmet>[]).map((ProHizmet h) => h.ad.trim().toLowerCase()).toSet();
    final List<HizmetTaslagi>? secilen = await showModalBottomSheet<List<HizmetTaslagi>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => _HazirMenu(mevcut: mevcut),
    );
    if (secilen == null || secilen.isEmpty || !mounted) {
      return;
    }
    await _calistir((SupabaseClient i) async {
      final List<ProHizmet> tum = _hizmetler ?? <ProHizmet>[];
      final int baslangic = tum.fold<int>(0, (int enBuyuk, ProHizmet h) => h.sira > enBuyuk ? h.sira : enBuyuk);
      final List<Map<String, dynamic>> satirlar = await i
          .from('hizmetler')
          .insert(<Map<String, dynamic>>[
            for (int n = 0; n < secilen.length; n++)
              <String, dynamic>{...secilen[n].kayit(), 'salon_id': widget.salon.id, 'sira': baslangic + n + 1},
          ])
          .select(ProHizmet.sutunlar);
      if (mounted) {
        setState(() => _hizmetler = <ProHizmet>[...tum, ...satirlar.map(ProHizmet.json)]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${satirlar.length} hizmet menüye eklendi.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final List<ProHizmet>? hizmetler = _hizmetler;
    final Object? hata = _hata;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonPalet.ivoire),
      child: Scaffold(
        backgroundColor: r.zemin,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: <Widget>[
              MaisonUstSatir(
                sol: MaisonYuvarlakDugme(
                  ikon: Icons.arrow_back,
                  etiket: 'Geri',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                baslik: 'Hizmetler',
                sag: _sahibim && hizmetler != null && hizmetler.isNotEmpty
                    ? MaisonYuvarlakDugme(
                        ikon: Icons.add,
                        etiket: 'Hizmet ekle',
                        onTap: _isleniyor ? null : () => _ekleDuzenle(),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              if (hata != null && hizmetler == null)
                MaisonHataKutusu(maisonHataMetni(hata), tekrar: _tekrarDene)
              else if (hizmetler == null)
                const MaisonYukleniyor()
              else if (hizmetler.isEmpty)
                _bosMenu(r)
              else
                ..._liste(r, hizmetler),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bosMenu(MaisonRenkler r) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: r.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: r.vurguYumusak, shape: BoxShape.circle),
            child: Icon(Icons.content_cut, color: r.vurgu),
          ),
          const SizedBox(height: 16),
          Text(
            'Hizmet menünü oluştur',
            style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
          ),
          const SizedBox(height: 8),
          Text(
            _sahibim
                ? 'Müşteriler randevu alırken bu menüden seçer. Hazır berber menüsünden seçip yalnız fiyatları yazabilirsin.'
                : 'Salon sahibi hizmet ekledikçe burada görünecek.',
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
          ),
          if (_sahibim) ...<Widget>[
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isleniyor ? null : _hazirMenu,
                child: const Text('Hazır menüden seç'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isleniyor ? null : () => _ekleDuzenle(),
                child: const Text('Kendim ekleyeceğim'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _liste(MaisonRenkler r, List<ProHizmet> hizmetler) {
    final List<ProHizmet> duz = _duzListe(hizmetler);
    final int aktif = duz.where((ProHizmet h) => h.aktif).length;
    return <Widget>[
      Text(
        '$aktif hizmet müşterilere görünüyor'
        '${duz.length > aktif ? ' · ${duz.length - aktif} pasif' : ''}',
        style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
      ),
      for (final HizmetKategorisi k in HizmetKategorisi.values)
        if (_grup(duz, k).isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          MaisonUstBaslik('${maisonBuyukHarf(k.ad)} · ${_grup(duz, k).length}'),
          const SizedBox(height: 10),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            proxyDecorator: (Widget cocuk, int i, Animation<double> a) => Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: const Color(0x33000000),
              borderRadius: BorderRadius.circular(18),
              child: cocuk,
            ),
            onReorderItem: (int eski, int yeni) => _sirala(k, eski, yeni),
            children: <Widget>[
              for (final (int i, ProHizmet h) in _grup(duz, k).indexed)
                Padding(
                  key: ValueKey<String>(h.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HizmetSatiri(
                    hizmet: h,
                    sira: i,
                    duzenlenebilir: _sahibim,
                    onTap: () => _ekleDuzenle(h),
                  ),
                ),
            ],
          ),
        ],
      const SizedBox(height: 16),
      if (_sahibim) ...<Widget>[
        Text(
          'Sırayı değiştirmek için sağdaki tutamağı basılı tutup sürükle. '
          'Pasif hizmetler müşterilere görünmez.',
          style: maisonGovde(12, renk: r.soluk, yukseklik: 1.45),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isleniyor ? null : _hazirMenu,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Hazır menüden ekle'),
          ),
        ),
      ],
    ];
  }
}

class _HizmetSatiri extends StatelessWidget {
  const _HizmetSatiri({
    required this.hizmet,
    required this.sira,
    required this.duzenlenebilir,
    required this.onTap,
  });

  final ProHizmet hizmet;
  final int sira;
  final bool duzenlenebilir;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? aciklama = hizmet.aciklama;
    return Material(
      color: r.kart,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: duzenlenebilir ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: r.cizgi),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            hizmet.ad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: maisonGovde(
                              15,
                              renk: hizmet.aktif ? r.yazi : r.soluk,
                              kalinlik: FontWeight.w600,
                              yukseklik: 1.3,
                            ),
                          ),
                        ),
                        if (!hizmet.aktif) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.cizgi,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Pasif', style: maisonGovde(11, renk: r.soluk, kalinlik: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${maisonSure(hizmet.sureDk)} · ${maisonPara(hizmet.fiyat, 'TRY')}',
                      style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3),
                    ),
                    if (aciklama != null && aciklama.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          aciklama.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3),
                        ),
                      ),
                  ],
                ),
              ),
              if (duzenlenebilir)
                ReorderableDragStartListener(
                  index: sira,
                  child: Semantics(
                    label: 'Sürükleyip sırala',
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.drag_indicator, color: r.soluk),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hizmet formunun sonucu: kaydedilecek taslak ya da silme isteği.
class _HizmetKarari {
  const _HizmetKarari({this.taslak, this.sil = false});

  final HizmetTaslagi? taslak;
  final bool sil;
}

class _HizmetFormu extends StatefulWidget {
  const _HizmetFormu({this.hizmet});

  final ProHizmet? hizmet;

  @override
  State<_HizmetFormu> createState() => _HizmetFormuState();
}

class _HizmetFormuState extends State<_HizmetFormu> {
  static const List<int> _hazirSureler = <int>[15, 20, 30, 45, 60, 90];

  late final TextEditingController _ad = TextEditingController(text: widget.hizmet?.ad ?? '');
  late final TextEditingController _fiyat = TextEditingController(
    text: widget.hizmet == null ? '' : maisonFiyatYaz(widget.hizmet!.fiyat),
  );
  late final TextEditingController _aciklama = TextEditingController(text: widget.hizmet?.aciklama ?? '');
  late HizmetKategorisi _kategori = widget.hizmet?.kategori ?? HizmetKategorisi.sac;
  late int _sure = widget.hizmet?.sureDk ?? 30;
  late bool _aktif = widget.hizmet?.aktif ?? true;
  String? _uyari;

  @override
  void dispose() {
    _ad.dispose();
    _fiyat.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  void _sureDegistir(int fark) {
    setState(() => _sure = (_sure + fark).clamp(5, 480).toInt());
  }

  void _kaydet() {
    final String ad = _ad.text.trim();
    final double? fiyat = maisonFiyatOku(_fiyat.text);
    if (ad.isEmpty) {
      setState(() => _uyari = 'Hizmetin adını yaz.');
      return;
    }
    if (fiyat == null) {
      setState(() => _uyari = 'Fiyatı rakamla yaz (ör. 400).');
      return;
    }
    if (fiyat > 99999) {
      setState(() => _uyari = 'Fiyat çok yüksek görünüyor.');
      return;
    }
    final String aciklama = _aciklama.text.trim();
    Navigator.of(context).pop(
      _HizmetKarari(
        taslak: HizmetTaslagi(
          ad: ad,
          kategori: _kategori,
          sureDk: _sure,
          fiyat: fiyat,
          aciklama: aciklama.isEmpty ? null : aciklama,
          aktif: _aktif,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Color hataRengi = Theme.of(context).colorScheme.error;
    final String? uyari = _uyari;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.hizmet == null ? 'Yeni hizmet' : 'Hizmeti düzenle',
                style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: 'HİZMET ADI',
                kontrol: _ad,
                ipucu: 'Ör. Saç kesimi',
                enFazla: 80,
                buyukHarf: TextCapitalization.sentences,
                eylem: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              const MaisonUstBaslik('KATEGORİ'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final HizmetKategorisi k in HizmetKategorisi.values)
                    ChoiceChip(
                      label: Text(k.ad),
                      selected: _kategori == k,
                      onSelected: (bool _) => setState(() => _kategori = k),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const MaisonUstBaslik('SÜRE'),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  MaisonYuvarlakDugme(ikon: Icons.remove, etiket: '5 dakika azalt', onTap: () => _sureDegistir(-5)),
                  Expanded(
                    child: Text(
                      maisonSure(_sure),
                      textAlign: TextAlign.center,
                      style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
                    ),
                  ),
                  MaisonYuvarlakDugme(ikon: Icons.add, etiket: '5 dakika artır', onTap: () => _sureDegistir(5)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final int s in _hazirSureler)
                    ChoiceChip(
                      label: Text(maisonSure(s)),
                      selected: _sure == s,
                      onSelected: (bool _) => setState(() => _sure = s),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              MaisonAlan(
                etiket: 'FİYAT',
                kontrol: _fiyat,
                ipucu: 'Ör. 400',
                klavye: const TextInputType.numberWithOptions(decimal: true),
                eylem: TextInputAction.next,
                sonek: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text('₺', style: maisonGovde(16, renk: r.soluk, kalinlik: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: 'AÇIKLAMA (İSTEĞE BAĞLI)',
                kontrol: _aciklama,
                ipucu: 'Ör. Yıkama ve şekillendirme dahil',
                enFazla: 500,
                buyukHarf: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Müşterilere görünsün',
                          style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                        ),
                        Text(
                          'Kapalıyken menüde durur ama randevuda seçilemez.',
                          style: maisonGovde(12, renk: r.soluk, yukseklik: 1.35),
                        ),
                      ],
                    ),
                  ),
                  MaisonAnahtar(
                    deger: _aktif,
                    etiket: 'Müşterilere görünsün',
                    onChanged: (bool yeni) => setState(() => _aktif = yeni),
                  ),
                ],
              ),
              if (uyari != null) ...<Widget>[
                const SizedBox(height: 14),
                MaisonHataKutusu(uyari),
              ],
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  if (widget.hizmet != null)
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(const _HizmetKarari(sil: true)),
                      icon: Icon(Icons.delete_outline, color: hataRengi),
                      label: Text('Sil', style: maisonGovde(14, renk: hataRengi, kalinlik: FontWeight.w600)),
                    ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: FilledButton(onPressed: _kaydet, child: const Text('Kaydet')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hazır berber menüsü: seçilen kalemlere fiyat yazılır, hepsi birden eklenir.
class _HazirMenu extends StatefulWidget {
  const _HazirMenu({required this.mevcut});

  /// Menüde zaten olan hizmet adları (küçük harfle).
  final Set<String> mevcut;

  @override
  State<_HazirMenu> createState() => _HazirMenuState();
}

class _HazirMenuState extends State<_HazirMenu> {
  final Map<int, TextEditingController> _fiyatlar = <int, TextEditingController>{};
  final Set<int> _secili = <int>{};
  String? _uyari;

  @override
  void dispose() {
    for (final TextEditingController k in _fiyatlar.values) {
      k.dispose();
    }
    super.dispose();
  }

  TextEditingController _fiyat(int i) => _fiyatlar.putIfAbsent(i, TextEditingController.new);

  void _ekle() {
    if (_secili.isEmpty) {
      setState(() => _uyari = 'En az bir hizmet seç.');
      return;
    }
    final List<HizmetTaslagi> taslaklar = <HizmetTaslagi>[];
    for (final int i in _secili.toList()..sort()) {
      final HizmetSablonu s = HizmetSablonu.berber[i];
      final double? fiyat = maisonFiyatOku(_fiyat(i).text);
      if (fiyat == null) {
        setState(() => _uyari = '${s.ad} için fiyat yaz.');
        return;
      }
      taslaklar.add(HizmetTaslagi(ad: s.ad, kategori: s.kategori, sureDk: s.sureDk, fiyat: fiyat));
    }
    Navigator.of(context).pop(taslaklar);
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? uyari = _uyari;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text('Hazır menü', style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Sunduğun hizmetleri işaretle ve fiyatını yaz. Süreleri sonra değiştirebilirsin.',
                  style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 20, 8),
                  itemCount: HizmetSablonu.berber.length,
                  itemBuilder: (BuildContext context, int i) {
                    final HizmetSablonu s = HizmetSablonu.berber[i];
                    final bool menudeVar = widget.mevcut.contains(s.ad.toLowerCase());
                    final bool secili = _secili.contains(i);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: <Widget>[
                          Checkbox(
                            value: secili,
                            onChanged: menudeVar
                                ? null
                                : (bool? yeni) => setState(() {
                                      if (yeni ?? false) {
                                        _secili.add(i);
                                      } else {
                                        _secili.remove(i);
                                      }
                                    }),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  s.ad,
                                  style: maisonGovde(
                                    15,
                                    renk: menudeVar ? r.soluk : r.yazi,
                                    kalinlik: FontWeight.w500,
                                    yukseklik: 1.3,
                                  ),
                                ),
                                Text(
                                  menudeVar ? 'Menünde var' : '${s.kategori.ad} · ${maisonSure(s.sureDk)}',
                                  style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 104,
                            child: TextField(
                              controller: _fiyat(i),
                              enabled: secili,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.end,
                              style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w500),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: secili ? 'Fiyat' : '',
                                hintStyle: maisonGovde(14, renk: r.soluk),
                                suffixText: '₺',
                                filled: true,
                                fillColor: r.girdi,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: r.cizgi),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: r.cizgi),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: r.cizgi.withValues(alpha: 0.5)),
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
              if (uyari != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: MaisonHataKutusu(uyari),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _ekle,
                    child: Text(_secili.isEmpty ? 'Menüye ekle' : '${_secili.length} hizmeti ekle'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
