import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../isletme.dart';
import '../salon.dart';
import 'usta_ekrani.dart';

/// Ekip: ustalar, haftalık saat özetleri, sıralama ve yeni usta.
class EkipEkrani extends StatefulWidget {
  const EkipEkrani({super.key, required this.salon, this.salonDegisti});

  final ProSalon salon;

  /// Usta salondan ayrılınca Makas Pro açılışı yeniden yüklenir.
  final VoidCallback? salonDegisti;

  @override
  State<EkipEkrani> createState() => _EkipEkraniState();
}

class _EkipEkraniState extends State<EkipEkrani> {
  List<ProUsta>? _ustalar;
  Map<String, List<CalismaAraligi>> _saatler = <String, List<CalismaAraligi>>{};
  Set<String> _davetliler = <String>{};
  Object? _hata;
  bool _isleniyor = false;

  bool get _sahibim => widget.salon.sahibim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ustalar == null && _hata == null) {
      _yukle();
    }
  }

  Future<void> _yukle() async {
    try {
      final SupabaseClient i = await OturumKapsami.oku(context).istemciGerekli();
      final List<Object?> sonuc = await Future.wait<Object?>(<Future<Object?>>[
        i
            .from('ustalar')
            .select(ProUsta.sutunlar)
            .eq('salon_id', widget.salon.id)
            .order('sira', ascending: true)
            .order('olusturuldu', ascending: true),
        i.from('calisma_saatleri').select('usta_id, gun, baslangic, bitis').eq('salon_id', widget.salon.id),
        if (_sahibim)
          i
              .from('usta_davetleri')
              .select('usta_id')
              .eq('salon_id', widget.salon.id)
              .gt('bitis', DateTime.now().toUtc().toIso8601String()),
      ]);
      final Map<String, List<CalismaAraligi>> saatler = <String, List<CalismaAraligi>>{};
      for (final Map<String, dynamic> m in _satirlar(sonuc[1])) {
        final String? usta = m['usta_id'] as String?;
        if (usta != null) {
          (saatler[usta] ??= <CalismaAraligi>[]).add(CalismaAraligi.json(m));
        }
      }
      final Set<String> davetliler = sonuc.length > 2
          ? _satirlar(sonuc[2]).map((Map<String, dynamic> m) => m['usta_id']).whereType<String>().toSet()
          : <String>{};
      if (mounted) {
        setState(() {
          _ustalar = _satirlar(sonuc[0]).map(ProUsta.json).toList();
          _saatler = saatler;
          _davetliler = davetliler;
          _hata = null;
        });
      }
    } catch (hata) {
      if (mounted) {
        setState(() => _hata = hata);
      }
    }
  }

  static List<Map<String, dynamic>> _satirlar(Object? liste) {
    if (liste is! List) {
      return <Map<String, dynamic>>[];
    }
    return liste.whereType<Map<String, dynamic>>().toList();
  }

  void _tekrarDene() {
    setState(() {
      _hata = null;
      _ustalar = null;
    });
    _yukle();
  }

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

  Future<void> _ac(ProUsta usta) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => UstaEkrani(salon: widget.salon, usta: usta, salonDegisti: widget.salonDegisti),
      ),
    );
    if (mounted) {
      await _yukle();
    }
  }

  Future<void> _sirala(int eski, int yeni) async {
    final List<ProUsta>? tum = _ustalar;
    if (tum == null || !_sahibim || _isleniyor) {
      return;
    }
    // onReorderItem: yeni, taşınan öğe çıkarıldıktan sonraki konumdur.
    final int hedef = yeni;
    if (hedef == eski) {
      return;
    }
    final List<ProUsta> liste = List<ProUsta>.of(tum);
    liste.insert(hedef, liste.removeAt(eski));
    setState(() => _ustalar = <ProUsta>[
          for (int i = 0; i < liste.length; i++) liste[i].copyWith(sira: i + 1),
        ]);
    await _calistir((SupabaseClient i) async {
      try {
        await i.rpc('usta_sirala', params: <String, dynamic>{
          'p_salon': widget.salon.id,
          'p_ustalar': liste.map((ProUsta u) => u.id).toList(),
        });
      } catch (_) {
        if (mounted) {
          setState(() => _ustalar = tum);
        }
        rethrow;
      }
    });
  }

  /// Yeni usta: ad ve unvan sorulur, kaydedilince ayrıntı sayfası açılır.
  Future<void> _yeniUsta() async {
    if (!_sahibim || _isleniyor) {
      return;
    }
    final MaisonRenkler r = MaisonRenkler.of(context);
    final (String, String?)? bilgi = await showModalBottomSheet<(String, String?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => const _YeniUstaFormu(),
    );
    if (bilgi == null || !mounted) {
      return;
    }
    ProUsta? eklenen;
    await _calistir((SupabaseClient i) async {
      final List<ProUsta> tum = _ustalar ?? <ProUsta>[];
      final int sira = tum.fold<int>(0, (int enBuyuk, ProUsta u) => u.sira > enBuyuk ? u.sira : enBuyuk) + 1;
      final Map<String, dynamic> satir = await i
          .from('ustalar')
          .insert(<String, dynamic>{
            'salon_id': widget.salon.id,
            'ad': bilgi.$1,
            'unvan': bilgi.$2,
            'sira': sira,
          })
          .select(ProUsta.sutunlar)
          .single();
      eklenen = ProUsta.json(satir);
    });
    final ProUsta? yeni = eklenen;
    if (yeni != null && mounted) {
      await _ac(yeni);
    }
  }

  /// Salon sahibi kendini ekibe ekler (müşteri kabul ediyorsa).
  Future<void> _beniEkle() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final String? ben = oturum.kullanici?.id;
    if (ben == null) {
      return;
    }
    ProUsta? eklenen;
    await _calistir((SupabaseClient i) async {
      final List<ProUsta> tum = _ustalar ?? <ProUsta>[];
      final Map<String, dynamic> satir = await i
          .from('ustalar')
          .insert(<String, dynamic>{
            'salon_id': widget.salon.id,
            'kullanici_id': ben,
            'ad': oturum.adSoyad.isEmpty ? 'Ben' : oturum.adSoyad,
            'unvan': 'Salon sahibi',
            'sira': 0,
          })
          .select(ProUsta.sutunlar)
          .single();
      eklenen = ProUsta.json(satir);
      if (mounted) {
        setState(() => _ustalar = <ProUsta>[eklenen!, ...tum]);
      }
    });
    final ProUsta? yeni = eklenen;
    if (yeni != null && mounted) {
      await _ac(yeni);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final List<ProUsta>? ustalar = _ustalar;
    final Object? hata = _hata;
    final String? ben = OturumKapsami.of(context).kullanici?.id;
    final bool benEkipte = ustalar?.any((ProUsta u) => u.kullaniciId != null && u.kullaniciId == ben) ?? true;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonPalet.ivoire),
      child: Scaffold(
        backgroundColor: r.zemin,
        body: SafeArea(
          child: RefreshIndicator(
            color: r.vurgu,
            backgroundColor: r.kart,
            onRefresh: _yukle,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: <Widget>[
                MaisonUstSatir(
                  sol: MaisonYuvarlakDugme(
                    ikon: Icons.arrow_back,
                    etiket: 'Geri',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  baslik: 'Ekip',
                  sag: _sahibim
                      ? MaisonYuvarlakDugme(ikon: Icons.person_add_alt, etiket: 'Usta ekle', onTap: _yeniUsta)
                      : null,
                ),
                const SizedBox(height: 18),
                if (hata != null && ustalar == null)
                  MaisonHataKutusu(maisonHataMetni(hata), tekrar: _tekrarDene)
                else if (ustalar == null)
                  const MaisonYukleniyor()
                else ...<Widget>[
                  if (_sahibim && !benEkipte) ...<Widget>[
                    _BeniEkleKarti(isleniyor: _isleniyor, onEkle: _beniEkle),
                    const SizedBox(height: 16),
                  ],
                  if (ustalar.isEmpty)
                    MaisonBosDurum(
                      ikon: Icons.groups_outlined,
                      baslik: 'Ekibini kur',
                      aciklama: _sahibim
                          ? 'Salonunda çalışan ustaları ekle; her birinin saatlerini ve yaptığı hizmetleri belirle.'
                          : 'Salon sahibi ustaları ekledikçe burada görünecek.',
                      dugme: _sahibim ? 'Usta ekle' : null,
                      onDugme: _sahibim ? _yeniUsta : null,
                    )
                  else ...<Widget>[
                    MaisonUstBaslik('${ustalar.length} USTA'),
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
                        borderRadius: BorderRadius.circular(20),
                        child: cocuk,
                      ),
                      onReorderItem: _sirala,
                      children: <Widget>[
                        for (final (int i, ProUsta u) in ustalar.indexed)
                          Padding(
                            key: ValueKey<String>(u.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _UstaKarti(
                              usta: u,
                              sira: i,
                              saatler: _saatler[u.id] ?? const <CalismaAraligi>[],
                              ben: u.kullaniciId != null && u.kullaniciId == ben,
                              davetli: _davetliler.contains(u.id),
                              siralanabilir: _sahibim,
                              onTap: () => _ac(u),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sahibim
                          ? 'Ayrıntı ve çalışma saatleri için ustaya dokun. Sıra, müşterinin ekip listesinde '
                              've "Fark etmez" seçildiğinde hangi ustaya önce bakılacağında kullanılır.'
                          : 'Ekibi yalnız salon sahibi düzenleyebilir.',
                      style: maisonGovde(12, renk: r.soluk, yukseklik: 1.45),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BeniEkleKarti extends StatelessWidget {
  const _BeniEkleKarti({required this.isleniyor, required this.onEkle});

  final bool isleniyor;
  final VoidCallback onEkle;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: r.vurguYumusak,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Sen de müşteri alıyor musun?',
            style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            'Kendini ekibe eklersen müşteriler senden de randevu alabilir.',
            style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: isleniyor ? null : onEkle,
                child: const Text('Kendimi ekibe ekle'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UstaKarti extends StatelessWidget {
  const _UstaKarti({
    required this.usta,
    required this.sira,
    required this.saatler,
    required this.ben,
    required this.davetli,
    required this.siralanabilir,
    required this.onTap,
  });

  final ProUsta usta;
  final int sira;
  final List<CalismaAraligi> saatler;
  final bool ben;
  final bool davetli;
  final bool siralanabilir;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final List<String> ozet = maisonHaftaOzeti(saatler);
    final String? unvan = usta.unvan;
    final List<String> rozetler = <String>[
      if (ben) 'Sen',
      if (!usta.aktif) 'Pasif',
      if (usta.hesapBagli && !ben) 'Makas Pro\'da',
      if (!usta.hesapBagli && davetli) 'Davet bekliyor',
    ];
    return Material(
      color: r.kart,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: r.cizgi),
          ),
          child: Row(
            children: <Widget>[
              Opacity(
                opacity: usta.aktif ? 1 : 0.5,
                child: MaisonAvatar(basHarfler: usta.basHarfler, boyut: 56, fotoUrl: usta.fotoUrl),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      usta.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(16, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                    ),
                    if (unvan != null && unvan.trim().isNotEmpty)
                      Text(
                        unvan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      ozet.isEmpty ? 'Çalışma saati eklenmedi' : ozet.first + (ozet.length > 1 ? ' …' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(
                        12,
                        renk: ozet.isEmpty ? Theme.of(context).colorScheme.error : r.soluk,
                        kalinlik: FontWeight.w500,
                        yukseklik: 1.3,
                      ),
                    ),
                    if (rozetler.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <Widget>[
                          for (final String rozet in rozetler)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: rozet == 'Pasif' ? r.cizgi : r.vurguYumusak,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                rozet,
                                style: maisonGovde(
                                  11,
                                  renk: rozet == 'Pasif' ? r.soluk : r.vurgu,
                                  kalinlik: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (siralanabilir)
                ReorderableDragStartListener(
                  index: sira,
                  child: Semantics(
                    label: 'Sürükleyip sırala',
                    child: SizedBox(width: 44, height: 44, child: Icon(Icons.drag_indicator, color: r.soluk)),
                  ),
                )
              else
                Icon(Icons.chevron_right, color: r.soluk),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yeni usta için ad ve unvan.
class _YeniUstaFormu extends StatefulWidget {
  const _YeniUstaFormu();

  @override
  State<_YeniUstaFormu> createState() => _YeniUstaFormuState();
}

class _YeniUstaFormuState extends State<_YeniUstaFormu> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _unvan = TextEditingController(text: 'Usta');
  String? _uyari;

  @override
  void dispose() {
    _ad.dispose();
    _unvan.dispose();
    super.dispose();
  }

  void _kaydet() {
    final String ad = _ad.text.trim();
    if (ad.isEmpty) {
      setState(() => _uyari = 'Ustanın adını yaz.');
      return;
    }
    final String unvan = _unvan.text.trim();
    Navigator.of(context).pop((ad, unvan.isEmpty ? null : unvan));
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? uyari = _uyari;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Yeni usta', style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Kaydedince çalışma saatlerini ve yaptığı hizmetleri belirleyeceksin.',
                style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
              ),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: 'AD SOYAD',
                kontrol: _ad,
                ipucu: 'Ör. Mehmet Yılmaz',
                enFazla: 60,
                buyukHarf: TextCapitalization.words,
                eylem: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              MaisonAlan(
                etiket: 'UNVAN',
                kontrol: _unvan,
                ipucu: 'Ör. Kıdemli usta',
                enFazla: 60,
                buyukHarf: TextCapitalization.sentences,
                eylem: TextInputAction.done,
                gonder: (String _) => _kaydet(),
              ),
              if (uyari != null) ...<Widget>[
                const SizedBox(height: 12),
                MaisonHataKutusu(uyari),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(onPressed: _kaydet, child: const Text('Ekle ve saatlerini ayarla')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
