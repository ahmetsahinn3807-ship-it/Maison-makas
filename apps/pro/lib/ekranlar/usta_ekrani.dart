import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, SupabaseClient;

import '../isletme.dart';
import '../salon.dart';
import 'calisma_saatleri_ekrani.dart';

/// Bir ustanın ayrıntısı: fotoğraf, bilgiler, çalışma saatleri, yaptığı hizmetler ve Makas Pro hesabı.
class UstaEkrani extends StatefulWidget {
  const UstaEkrani({super.key, required this.salon, required this.usta, this.salonDegisti});

  final ProSalon salon;
  final ProUsta usta;

  /// Usta salondan ayrılınca Makas Pro açılışı yeniden yüklenir.
  final VoidCallback? salonDegisti;

  @override
  State<UstaEkrani> createState() => _UstaEkraniState();
}

class _UstaEkraniState extends State<UstaEkrani> {
  late ProUsta _usta = widget.usta;
  List<CalismaAraligi>? _saatler;
  List<ProHizmet> _hizmetler = <ProHizmet>[];
  Set<String> _yaptiklari = <String>{};
  DateTime? _davetBitis;
  bool _sahipEkipte = true;
  Object? _hata;
  String? _islem;

  bool get _sahibim => widget.salon.sahibim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_saatler == null && _hata == null) {
      _yukle();
    }
  }

  Future<void> _yukle() async {
    try {
      final MaisonOturum oturum = OturumKapsami.oku(context);
      final SupabaseClient i = await oturum.istemciGerekli();
      final String? ben = oturum.kullanici?.id;
      final List<Object?> sonuc = await Future.wait<Object?>(<Future<Object?>>[
        i.from('ustalar').select(ProUsta.sutunlar).eq('id', widget.usta.id).single(),
        i.from('calisma_saatleri').select('gun, baslangic, bitis').eq('usta_id', widget.usta.id),
        i
            .from('hizmetler')
            .select(ProHizmet.sutunlar)
            .eq('salon_id', widget.salon.id)
            .order('sira', ascending: true)
            .order('ad', ascending: true),
        i.from('usta_hizmet').select('hizmet_id').eq('usta_id', widget.usta.id),
        if (_sahibim) i.from('usta_davetleri').select('bitis').eq('usta_id', widget.usta.id).maybeSingle(),
        if (_sahibim && ben != null)
          i.from('ustalar').select('id').eq('salon_id', widget.salon.id).eq('kullanici_id', ben),
      ]);
      final Object? davet = _sahibim ? sonuc[4] : null;
      final Object? benimSatirim = _sahibim && ben != null ? sonuc[5] : null;
      if (!mounted) {
        return;
      }
      setState(() {
        _usta = ProUsta.json(sonuc[0]! as Map<String, dynamic>);
        _saatler = maisonAralikSirala(_satirlar(sonuc[1]).map(CalismaAraligi.json));
        _hizmetler = _satirlar(sonuc[2]).map(ProHizmet.json).toList();
        _yaptiklari =
            _satirlar(sonuc[3]).map((Map<String, dynamic> m) => m['hizmet_id']).whereType<String>().toSet();
        final Object? bitis = davet is Map<String, dynamic> ? davet['bitis'] : null;
        final DateTime? davetBitis = bitis is String ? DateTime.tryParse(bitis)?.toLocal() : null;
        _davetBitis = davetBitis != null && davetBitis.isAfter(DateTime.now()) ? davetBitis : null;
        _sahipEkipte = benimSatirim is List && benimSatirim.isNotEmpty;
        _hata = null;
      });
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
      _saatler = null;
    });
    _yukle();
  }

  Future<void> _calistir(String islem, Future<void> Function(SupabaseClient i) gorev) async {
    if (_islem != null) {
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    setState(() => _islem = islem);
    try {
      await gorev(await oturum.istemciGerekli());
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(_hataMetni(hata))));
    } finally {
      if (mounted) {
        setState(() => _islem = null);
      }
    }
  }

  String _hataMetni(Object hata) {
    if (hata is PostgrestException && hata.code == '23503') {
      return 'Bu ustanın randevu kayıtları var; silinemez. Bunun yerine "Müşterilere görünsün"ü kapat.';
    }
    if (hata is PostgrestException && hata.code == '23505') {
      return 'Hesabın bu salonda zaten bir ustaya bağlı.';
    }
    return maisonHataMetni(hata);
  }

  Future<void> _ustaGuncelle(SupabaseClient i, Map<String, dynamic> alanlar) async {
    final Map<String, dynamic> satir = await i
        .from('ustalar')
        .update(alanlar)
        .eq('id', _usta.id)
        .select(ProUsta.sutunlar)
        .single();
    if (mounted) {
      setState(() => _usta = ProUsta.json(satir));
    }
  }

  // ---------------------------------------------------------------- Fotoğraf

  Future<void> _fotoDegistir() async {
    if (!_sahibim || _islem != null) {
      return;
    }
    final String? eski = _usta.fotoUrl;
    final FotoIslemi? islem = await maisonFotoIslemiSor(context, baslik: 'Ustanın fotoğrafı', kaldirilabilir: eski != null);
    if (islem == null || islem == FotoIslemi.odak || !mounted) {
      return;
    }
    if (islem == FotoIslemi.kaldir) {
      await _calistir('foto', (SupabaseClient i) async {
        await _ustaGuncelle(i, <String, dynamic>{'foto_url': null});
        await maisonFotoSil(i, eski);
      });
      return;
    }
    SecilenFoto? foto;
    try {
      foto = await maisonFotoSec(islem, FotoBoyu.avatar);
    } catch (hata) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
      }
      return;
    }
    final SecilenFoto? secilen = foto;
    if (secilen == null || !mounted) {
      return;
    }
    await _calistir('foto', (SupabaseClient i) async {
      final String url = await maisonFotoYukle(
        i,
        kova: 'salon',
        klasor: '${widget.salon.id}/ekip',
        ad: 'usta',
        foto: secilen,
      );
      await _ustaGuncelle(i, <String, dynamic>{'foto_url': url});
      await maisonFotoSil(i, eski);
    });
  }

  // ---------------------------------------------------------------- Bilgiler

  Future<void> _bilgileriDuzenle() async {
    if (!_sahibim || _islem != null) {
      return;
    }
    final MaisonRenkler r = MaisonRenkler.of(context);
    final _UstaBilgisi? bilgi = await showModalBottomSheet<_UstaBilgisi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => _UstaBilgiFormu(usta: _usta),
    );
    if (bilgi == null || !mounted) {
      return;
    }
    await _calistir('bilgi', (SupabaseClient i) async {
      await _ustaGuncelle(i, <String, dynamic>{
        'ad': bilgi.ad,
        'unvan': bilgi.unvan,
        'uzmanlik': bilgi.uzmanlik,
      });
    });
  }

  Future<void> _aktifDegistir(bool yeni) async {
    if (!_sahibim) {
      return;
    }
    await _calistir('aktif', (SupabaseClient i) async {
      await _ustaGuncelle(i, <String, dynamic>{'aktif': yeni});
    });
  }

  // ---------------------------------------------------------------- Saatler ve hizmetler

  Future<void> _saatleriDuzenle() async {
    final List<CalismaAraligi>? saatler = _saatler;
    if (!_sahibim || saatler == null || _islem != null) {
      return;
    }
    final List<CalismaAraligi>? yeni = await Navigator.of(context).push<List<CalismaAraligi>>(
      MaterialPageRoute<List<CalismaAraligi>>(
        builder: (BuildContext context) => CalismaSaatleriEkrani(usta: _usta, saatler: saatler),
      ),
    );
    if (yeni != null && mounted) {
      setState(() => _saatler = maisonAralikSirala(yeni));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışma saatleri kaydedildi.')));
    }
  }

  Future<void> _hizmetleriDuzenle() async {
    if (!_sahibim || _islem != null) {
      return;
    }
    if (_hizmetler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce Hizmetler ekranından hizmet menünü oluştur.')),
      );
      return;
    }
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Set<String>? secim = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => _UstaHizmetleriFormu(
        usta: _usta,
        hizmetler: _hizmetler,
        secili: _yaptiklari,
      ),
    );
    if (secim == null || !mounted) {
      return;
    }
    await _calistir('hizmet', (SupabaseClient i) async {
      await i.rpc('usta_hizmetlerini_kaydet', params: <String, dynamic>{
        'p_usta': _usta.id,
        'p_hizmetler': secim.toList(),
      });
      if (mounted) {
        setState(() => _yaptiklari = secim);
      }
    });
  }

  // ---------------------------------------------------------------- Hesap

  Future<void> _davetOlustur() async {
    if (!_sahibim || _islem != null) {
      return;
    }
    String? kod;
    await _calistir('davet', (SupabaseClient i) async {
      final Object? sonuc = await i.rpc('usta_davet_kodu_olustur', params: <String, dynamic>{'p_usta': _usta.id});
      kod = sonuc is String ? sonuc : null;
      if (mounted) {
        setState(() => _davetBitis = DateTime.now().add(const Duration(days: 7)));
      }
    });
    final String? olusan = kod;
    if (olusan != null && mounted) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => _DavetKoduPenceresi(kod: olusan, ustaAdi: _usta.ad),
      );
    }
  }

  Future<void> _beniBagla() async {
    final String? ben = OturumKapsami.oku(context).kullanici?.id;
    if (!_sahibim || ben == null) {
      return;
    }
    await _calistir('hesap', (SupabaseClient i) async {
      await _ustaGuncelle(i, <String, dynamic>{'kullanici_id': ben});
      if (mounted) {
        setState(() => _sahipEkipte = true);
      }
    });
  }

  Future<void> _baglantiyiKaldir({required bool kendim}) async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool? eminim = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: r.kart,
        title: Text(
          kendim ? 'Salondan ayrılıyor musun?' : 'Hesap bağlantısı kaldırılsın mı?',
          style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600),
        ),
        content: Text(
          kendim
              ? 'Bu salonun takvimini artık göremezsin. Geri dönmek için salon sahibinden yeni bir davet kodu istemen gerekir.'
              : '${_usta.ad} artık Makas Pro\'dan bu salonun takvimini göremez. Usta kaydı, saatleri ve randevuları kalır.',
          style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(kendim ? 'Ayrıl' : 'Kaldır', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (eminim != true || !mounted) {
      return;
    }
    final NavigatorState gezgin = Navigator.of(context);
    final VoidCallback? salonDegisti = widget.salonDegisti;
    bool oldu = false;
    await _calistir('hesap', (SupabaseClient i) async {
      await i.rpc('usta_hesabini_ayir', params: <String, dynamic>{'p_usta': _usta.id});
      oldu = true;
      if (mounted) {
        setState(() => _usta = _usta.copyWith(hesapSil: true));
      }
    });
    if (oldu && kendim) {
      // Ayrılan usta salonu artık göremez; açılış ekranı yeniden yüklenir.
      gezgin.popUntil((Route<dynamic> rota) => rota.isFirst);
      salonDegisti?.call();
    }
  }

  Future<void> _sil() async {
    if (!_sahibim || _islem != null) {
      return;
    }
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool? eminim = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: r.kart,
        title: Text('${_usta.ad} silinsin mi?', style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
        content: Text(
          'Usta, saatleri ve hizmet seçimleriyle birlikte silinir. Randevu kaydı olan usta silinemez; '
          'onun yerine "Müşterilere görünsün"ü kapatabilirsin.',
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
    final NavigatorState gezgin = Navigator.of(context);
    bool silindi = false;
    await _calistir('sil', (SupabaseClient i) async {
      await i.from('ustalar').delete().eq('id', _usta.id);
      silindi = true;
      await maisonFotoSil(i, _usta.fotoUrl);
    });
    if (silindi) {
      gezgin.pop();
    }
  }

  // ---------------------------------------------------------------- Ekran

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final List<CalismaAraligi>? saatler = _saatler;
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
                baslik: 'Usta',
              ),
              const SizedBox(height: 18),
              _profil(r),
              const SizedBox(height: 24),
              if (hata != null && saatler == null)
                MaisonHataKutusu(maisonHataMetni(hata), tekrar: _tekrarDene)
              else if (saatler == null)
                const MaisonYukleniyor()
              else ..._bolumler(r, saatler),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profil(MaisonRenkler r) {
    final String? unvan = _usta.unvan;
    final String? ben = OturumKapsami.of(context).kullanici?.id;
    final bool benim = _usta.kullaniciId != null && _usta.kullaniciId == ben;
    return Column(
      children: <Widget>[
        SizedBox(
          width: 96 + 14,
          height: 96 + 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Opacity(
                opacity: _usta.aktif ? 1 : 0.5,
                child: MaisonAvatar(basHarfler: _usta.basHarfler, boyut: 96, fotoUrl: _usta.fotoUrl),
              ),
              if (_sahibim)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Semantics(
                    button: true,
                    label: 'Ustanın fotoğrafını değiştir',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _islem == null ? _fotoDegistir : null,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: r.vurgu,
                              shape: BoxShape.circle,
                              border: Border.all(color: r.zemin, width: 2),
                            ),
                            child: _islem == 'foto'
                                ? Padding(
                                    padding: const EdgeInsets.all(7),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: r.vurguUstu),
                                  )
                                : Icon(Icons.photo_camera_outlined, size: 16, color: r.vurguUstu),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _usta.ad,
          textAlign: TextAlign.center,
          style: maisonBaslik(32, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
        ),
        if (unvan != null && unvan.trim().isNotEmpty)
          Text(unvan, textAlign: TextAlign.center, style: maisonGovde(14, renk: r.soluk, yukseklik: 1.4)),
        if (benim || !_usta.aktif) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            <String>[if (benim) 'Sen', if (!_usta.aktif) 'Müşterilere görünmüyor'].join(' · '),
            style: maisonGovde(12, renk: r.vurgu, kalinlik: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  List<Widget> _bolumler(MaisonRenkler r, List<CalismaAraligi> saatler) {
    final List<String> uzmanlik = _usta.uzmanlik;
    final List<ProHizmet> yaptigi = _yaptiklari.isEmpty
        ? _hizmetler
        : _hizmetler.where((ProHizmet h) => _yaptiklari.contains(h.id)).toList();
    return <Widget>[
      _Kart(
        baslik: 'BİLGİLER',
        eylem: _sahibim ? 'Düzenle' : null,
        onEylem: _bilgileriDuzenle,
        children: <Widget>[
          if (uzmanlik.isEmpty)
            Text(
              _sahibim ? 'Uzmanlık eklemek için Düzenle\'ye dokun (ör. Fade, Sakal tasarımı).' : 'Uzmanlık eklenmedi.',
              style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String u in uzmanlik)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: r.vurguYumusak, borderRadius: BorderRadius.circular(12)),
                    child: Text(u, style: maisonGovde(12, renk: r.vurgu, kalinlik: FontWeight.w600)),
                  ),
              ],
            ),
          const SizedBox(height: 12),
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
                      'Kapalıyken randevu alınamaz; geçmiş randevuları durur.',
                      style: maisonGovde(12, renk: r.soluk, yukseklik: 1.35),
                    ),
                  ],
                ),
              ),
              MaisonAnahtar(
                deger: _usta.aktif,
                etiket: 'Müşterilere görünsün',
                onChanged: (bool yeni) {
                  if (_sahibim && _islem == null) {
                    _aktifDegistir(yeni);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 14),
      _Kart(
        baslik: 'ÇALIŞMA SAATLERİ',
        eylem: _sahibim ? 'Düzenle' : null,
        onEylem: _saatleriDuzenle,
        children: <Widget>[
          if (saatler.isEmpty)
            Text(
              'Henüz saat girilmedi. Saat girilmeyen usta müşterilere randevu için görünmez.',
              style: maisonGovde(13, renk: Theme.of(context).colorScheme.error, yukseklik: 1.45),
            )
          else
            MaisonHaftalikSaatler(araliklar: saatler, bugun: DateTime.now().weekday),
        ],
      ),
      const SizedBox(height: 14),
      _Kart(
        baslik: 'YAPTIĞI HİZMETLER',
        eylem: _sahibim ? 'Düzenle' : null,
        onEylem: _hizmetleriDuzenle,
        children: <Widget>[
          Text(
            _hizmetler.isEmpty
                ? 'Hizmet menüsü henüz boş.'
                : _yaptiklari.isEmpty
                    ? 'Bütün hizmetler (sonradan eklenenler dahil)'
                    : '${yaptigi.length} hizmet',
            style: maisonGovde(14, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.4),
          ),
          if (_yaptiklari.isNotEmpty && yaptigi.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              yaptigi.map((ProHizmet h) => h.ad).join(' · '),
              style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
            ),
          ],
        ],
      ),
      const SizedBox(height: 14),
      _hesapKarti(r),
      if (_sahibim) ...<Widget>[
        const SizedBox(height: 24),
        Center(
          child: TextButton.icon(
            onPressed: _islem == null ? _sil : null,
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            label: Text(
              'Ustayı sil',
              style: maisonGovde(14, renk: Theme.of(context).colorScheme.error, kalinlik: FontWeight.w600),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _hesapKarti(MaisonRenkler r) {
    final String? ben = OturumKapsami.of(context).kullanici?.id;
    final bool benim = _usta.kullaniciId != null && _usta.kullaniciId == ben;
    final DateTime? davet = _davetBitis;
    final List<Widget> icerik;
    if (benim) {
      icerik = <Widget>[
        Text(
          'Bu senin hesabın. Bu ustaya alınan randevular Makas Pro\'da seninle eşleşir.',
          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
        ),
        if (!_sahibim) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _islem == null ? () => _baglantiyiKaldir(kendim: true) : null,
              child: Text(
                'Bu salondan ayrıl',
                style: maisonGovde(14, renk: Theme.of(context).colorScheme.error, kalinlik: FontWeight.w600),
              ),
            ),
          ),
        ],
      ];
    } else if (_usta.hesapBagli) {
      icerik = <Widget>[
        Text(
          'Kendi telefonundan Makas Pro\'ya giriyor ve yalnız kendi randevularını görüyor.',
          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
        ),
        if (_sahibim) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _islem == null ? () => _baglantiyiKaldir(kendim: false) : null,
              child: Text(
                'Hesap bağlantısını kaldır',
                style: maisonGovde(14, renk: Theme.of(context).colorScheme.error, kalinlik: FontWeight.w600),
              ),
            ),
          ),
        ],
      ];
    } else {
      icerik = <Widget>[
        Text(
          _sahibim
              ? '${_usta.ad} kendi telefonundan Makas Pro\'ya girip kendi randevularını görebilir. '
                  'Bunun için bir davet kodu oluştur ve ona gönder.'
              : 'Bu usta Makas Pro\'ya bağlı değil.',
          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
        ),
        if (_sahibim && davet != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Gönderdiğin kod ${davet.day} ${maisonAy(davet)} tarihine kadar geçerli.',
            style: maisonGovde(13, renk: r.vurgu, kalinlik: FontWeight.w500, yukseklik: 1.45),
          ),
        ],
        if (_sahibim) ...<Widget>[
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _islem == null ? _davetOlustur : null,
              icon: const Icon(Icons.key_outlined, size: 18),
              label: Text(davet == null ? 'Davet kodu oluştur' : 'Yeni kod oluştur'),
            ),
          ),
          if (!_sahipEkipte) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _islem == null ? _beniBagla : null,
                child: const Text('Bu usta benim'),
              ),
            ),
          ],
        ],
      ];
    }
    return _Kart(baslik: 'MAKAS PRO HESABI', children: icerik);
  }
}

class _Kart extends StatelessWidget {
  const _Kart({required this.baslik, required this.children, this.eylem, this.onEylem});

  final String baslik;
  final List<Widget> children;
  final String? eylem;
  final VoidCallback? onEylem;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? e = eylem;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 16),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: r.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: MaisonUstBaslik(baslik)),
              if (e != null)
                TextButton(onPressed: onEylem, child: Text(e))
              else
                const SizedBox(height: 44),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ],
      ),
    );
  }
}

/// Bilgi formunun sonucu.
class _UstaBilgisi {
  const _UstaBilgisi({required this.ad, required this.unvan, required this.uzmanlik});

  final String ad;
  final String? unvan;
  final List<String> uzmanlik;
}

class _UstaBilgiFormu extends StatefulWidget {
  const _UstaBilgiFormu({required this.usta});

  final ProUsta usta;

  @override
  State<_UstaBilgiFormu> createState() => _UstaBilgiFormuState();
}

class _UstaBilgiFormuState extends State<_UstaBilgiFormu> {
  late final TextEditingController _ad = TextEditingController(text: widget.usta.ad);
  late final TextEditingController _unvan = TextEditingController(text: widget.usta.unvan ?? '');
  final TextEditingController _yeniEtiket = TextEditingController();
  late final List<String> _uzmanlik = List<String>.of(widget.usta.uzmanlik);
  String? _uyari;

  @override
  void dispose() {
    _ad.dispose();
    _unvan.dispose();
    _yeniEtiket.dispose();
    super.dispose();
  }

  void _etiketDegistir(String etiket) {
    setState(() {
      if (_uzmanlik.contains(etiket)) {
        _uzmanlik.remove(etiket);
      } else if (_uzmanlik.length < 8) {
        _uzmanlik.add(etiket);
      }
    });
  }

  void _etiketEkle() {
    final String etiket = _yeniEtiket.text.trim();
    if (etiket.isEmpty) {
      return;
    }
    if (etiket.length > 30) {
      setState(() => _uyari = 'Uzmanlık en çok 30 harf olabilir.');
      return;
    }
    setState(() {
      if (!_uzmanlik.contains(etiket) && _uzmanlik.length < 8) {
        _uzmanlik.add(etiket);
      }
      _yeniEtiket.clear();
      _uyari = null;
    });
  }

  void _kaydet() {
    final String ad = _ad.text.trim();
    if (ad.isEmpty) {
      setState(() => _uyari = 'Ustanın adını yaz.');
      return;
    }
    final String unvan = _unvan.text.trim();
    Navigator.of(context).pop(
      _UstaBilgisi(ad: ad, unvan: unvan.isEmpty ? null : unvan, uzmanlik: List<String>.of(_uzmanlik)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? uyari = _uyari;
    final List<String> tumEtiketler = <String>[
      ...uzmanlikOnerileri,
      ..._uzmanlik.where((String e) => !uzmanlikOnerileri.contains(e)),
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Ustanın bilgileri', style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600)),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: 'AD SOYAD',
                kontrol: _ad,
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
                eylem: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              const MaisonUstBaslik('UZMANLIK (EN ÇOK 8)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String e in tumEtiketler)
                    FilterChip(
                      label: Text(e),
                      selected: _uzmanlik.contains(e),
                      onSelected: (bool _) => _etiketDegistir(e),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _yeniEtiket,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 30,
                      onSubmitted: (String _) => _etiketEkle(),
                      style: maisonGovde(15, renk: r.yazi),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Başka bir uzmanlık yaz',
                        hintStyle: maisonGovde(14, renk: r.soluk),
                        filled: true,
                        fillColor: r.girdi,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: r.cizgi),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: r.cizgi),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MaisonYuvarlakDugme(ikon: Icons.add, etiket: 'Uzmanlık ekle', onTap: _etiketEkle),
                ],
              ),
              if (uyari != null) ...<Widget>[
                const SizedBox(height: 12),
                MaisonHataKutusu(uyari),
              ],
              const SizedBox(height: 18),
              SizedBox(height: 52, child: FilledButton(onPressed: _kaydet, child: const Text('Kaydet'))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ustanın yaptığı hizmetler: hepsi ya da seçilenler.
class _UstaHizmetleriFormu extends StatefulWidget {
  const _UstaHizmetleriFormu({required this.usta, required this.hizmetler, required this.secili});

  final ProUsta usta;
  final List<ProHizmet> hizmetler;
  final Set<String> secili;

  @override
  State<_UstaHizmetleriFormu> createState() => _UstaHizmetleriFormuState();
}

class _UstaHizmetleriFormuState extends State<_UstaHizmetleriFormu> {
  late bool _hepsi = widget.secili.isEmpty;
  late final Set<String> _secili = widget.secili.isEmpty
      ? widget.hizmetler.map((ProHizmet h) => h.id).toSet()
      : Set<String>.of(widget.secili);
  String? _uyari;

  void _kaydet() {
    if (_hepsi) {
      Navigator.of(context).pop(<String>{});
      return;
    }
    if (_secili.isEmpty) {
      setState(() => _uyari = 'En az bir hizmet seç ya da "Bütün hizmetler"i aç.');
      return;
    }
    Navigator.of(context).pop(Set<String>.of(_secili));
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? uyari = _uyari;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '${widget.usta.ad} hangi hizmetleri yapıyor?',
                style: maisonBaslik(26, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Bütün hizmetler',
                          style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                        ),
                        Text(
                          'Sonradan eklenen hizmetler de dahil.',
                          style: maisonGovde(12, renk: r.soluk, yukseklik: 1.35),
                        ),
                      ],
                    ),
                  ),
                  MaisonAnahtar(
                    deger: _hepsi,
                    etiket: 'Bütün hizmetler',
                    onChanged: (bool yeni) => setState(() {
                      _hepsi = yeni;
                      _uyari = null;
                    }),
                  ),
                ],
              ),
            ),
            if (!_hepsi)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                  children: <Widget>[
                    for (final ProHizmet h in widget.hizmetler)
                      CheckboxListTile(
                        value: _secili.contains(h.id),
                        title: Text(h.ad, style: maisonGovde(15, renk: r.yazi)),
                        subtitle: Text(
                          '${h.kategori.ad} · ${maisonSure(h.sureDk)}${h.aktif ? '' : ' · pasif'}',
                          style: maisonGovde(12, renk: r.soluk),
                        ),
                        onChanged: (bool? yeni) => setState(() {
                          if (yeni ?? false) {
                            _secili.add(h.id);
                          } else {
                            _secili.remove(h.id);
                          }
                          _uyari = null;
                        }),
                      ),
                  ],
                ),
              ),
            if (uyari != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: MaisonHataKutusu(uyari),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(height: 52, child: FilledButton(onPressed: _kaydet, child: const Text('Kaydet'))),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oluşturulan davet kodunu gösterir; kopyalanabilir.
class _DavetKoduPenceresi extends StatelessWidget {
  const _DavetKoduPenceresi({required this.kod, required this.ustaAdi});

  final String kod;
  final String ustaAdi;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String mesajMetni =
        'Makas Pro davet kodun: $kod\n'
        'Makas Pro\'yu aç, hesabını oluştur, sonra "Davet kodum var"a dokunup bu kodu yaz. Kod 7 gün geçerli.';
    return AlertDialog(
      backgroundColor: r.kart,
      title: Text('Davet kodu', style: maisonBaslik(26, renk: r.yazi, kalinlik: FontWeight.w600)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Bu kodu $ustaAdi ile paylaş. Makas Pro\'da hesabını açtıktan sonra '
            '"Davet kodum var"a dokunup kodu yazacak.',
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: r.vurguYumusak,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              kod,
              textAlign: TextAlign.center,
              style: maisonBaslik(38, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.0, aralik: 3),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Kod 7 gün geçerli ve tek kullanımlık. Yeni kod oluşturursan eskisi geçersiz olur.',
            style: maisonGovde(12, renk: r.soluk, yukseklik: 1.45),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: mesajMetni));
            mesaj.showSnackBar(const SnackBar(content: Text('Davet mesajı kopyalandı.')));
          },
          child: const Text('Mesajı kopyala'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tamam')),
      ],
    );
  }
}
