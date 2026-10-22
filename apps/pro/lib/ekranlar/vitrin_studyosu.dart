import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../salon.dart';

/// Galeri fotoğraflarının kategorileri (veritabanındaki adlarla).
Map<String, String> get _kategoriler => <String, String>{
      for (final HizmetKategorisi k in HizmetKategorisi.values) k.kimlik: k.ad,
    };

/// Vitrin Stüdyosu: müşterinin gördüğü salon sayfasını işletme burada hazırlar.
/// Kapak (görünen kısmıyla), logo, galeri duvarı, vitrin filtresi ve tema. Değişiklikler hemen kaydedilir.
class VitrinStudyosu extends StatefulWidget {
  const VitrinStudyosu({super.key, required this.salon, required this.salonDegisti});

  final ProSalon salon;

  /// Salon yayına alınınca üst ekranın bilgisini yeniler.
  final VoidCallback salonDegisti;

  @override
  State<VitrinStudyosu> createState() => _VitrinStudyosuState();
}

class _VitrinStudyosuState extends State<VitrinStudyosu> {
  static const double _onizlemeGenislik = 150;
  static const double _onizlemeYukseklik = 300;

  /// Vitrin galerisinde en çok bu kadar fotoğraf durur (müşteri tarafı da bu kadarını okur).
  static const int _galeriSiniri = 60;

  Future<VitrinVerisi>? _ilkYukleme;
  VitrinVerisi? _veri;

  /// Süren iş: 'kapak', 'logo', 'galeri', 'ayar', 'yayin'; yoksa null.
  String? _islem;
  int _galeriBiten = 0;
  int _galeriToplam = 0;

  bool get _duzenleyebilir => widget.salon.sahibim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ilkYukleme ??= _yukle();
  }

  Future<VitrinVerisi> _yukle() async {
    final SupabaseClient i = await OturumKapsami.oku(context).istemciGerekli();
    final VitrinVerisi v = await VitrinVerisi.yukle(i, widget.salon.id);
    if (mounted) {
      setState(() => _veri = v);
    }
    return v;
  }

  void _tekrarDene() {
    setState(() {
      _veri = null;
      _ilkYukleme = _yukle();
    });
  }

  /// Ortak iş kalıbı: düğmeleri kilitler, hatayı gösterir, sonunda kilidi açar.
  Future<void> _calistir(String islem, Future<void> Function(SupabaseClient i, VitrinVerisi v) gorev) async {
    final VitrinVerisi? v = _veri;
    if (v == null || _islem != null) {
      return;
    }
    if (!_duzenleyebilir) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dl('Vitrini yalnız salon sahibi düzenleyebilir.', 'Only the salon owner can edit the showcase.'))),
      );
      return;
    }
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    final MaisonOturum oturum = OturumKapsami.oku(context);
    setState(() => _islem = islem);
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      await gorev(i, v);
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    } finally {
      if (mounted) {
        setState(() {
          _islem = null;
          _galeriBiten = 0;
          _galeriToplam = 0;
        });
      }
    }
  }

  /// Seçici açılmadan önce: veri hazır mı, başka iş sürüyor mu, kişi salonun sahibi mi?
  bool _duzenlemeBaslasin() {
    if (_veri == null || _islem != null) {
      return false;
    }
    if (!_duzenleyebilir) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dl('Vitrini yalnız salon sahibi düzenleyebilir.', 'Only the salon owner can edit the showcase.'))),
      );
      return false;
    }
    return true;
  }

  void _salonuGuncelle(VitrinSalonu yeni) {
    final VitrinVerisi? v = _veri;
    if (v != null && mounted) {
      setState(() => _veri = v.copyWith(salon: yeni));
    }
  }

  /// Salon satırını günceller. Hiçbir satır değişmezse (yetki yoksa) hata verir; sessizce kaybolmaz.
  Future<void> _salonaYaz(SupabaseClient i, Map<String, dynamic> alanlar) async {
    final List<Map<String, dynamic>> satirlar =
        await i.from('salonlar').update(alanlar).eq('id', widget.salon.id).select('id');
    if (satirlar.isEmpty) {
      throw MaisonHata(dl('Değişiklik kaydedilemedi: bu salonu düzenleme yetkin yok.', 'The change could not be saved: you are not allowed to edit this salon.'));
    }
  }

  // ---------------------------------------------------------------- Kapak

  Future<void> _kapakIslemi() async {
    if (!_duzenlemeBaslasin()) {
      return;
    }
    final VitrinVerisi v = _veri!;
    final String? eski = v.salon.kapakUrl;
    final FotoIslemi? islem = await maisonFotoIslemiSor(
      context,
      baslik: dl('Kapak fotoğrafı', 'Cover photo'),
      kaldirilabilir: eski != null,
      odakAyarlanabilir: eski != null,
    );
    if (islem == null || !mounted) {
      return;
    }
    if (islem == FotoIslemi.kaldir) {
      await _calistir('kapak', (SupabaseClient i, VitrinVerisi v) async {
        await _salonaYaz(i, <String, dynamic>{'kapak_url': null, 'kapak_odak_x': 0.5, 'kapak_odak_y': 0.5});
        await maisonFotoSil(i, eski);
        _salonuGuncelle(v.salon.copyWith(kapakSil: true, kapakOdak: const Offset(0.5, 0.5)));
      });
      return;
    }
    if (islem == FotoIslemi.odak) {
      if (eski == null) {
        return;
      }
      final Offset? odak = await maisonOdakSec(
        context,
        resim: NetworkImage(eski),
        baslangic: v.salon.kapakOdak,
        oran: 390 / 274,
      );
      if (odak == null || !mounted) {
        return;
      }
      await _calistir('kapak', (SupabaseClient i, VitrinVerisi v) async {
        await _salonaYaz(i, <String, dynamic>{'kapak_odak_x': odak.dx, 'kapak_odak_y': odak.dy});
        _salonuGuncelle(v.salon.copyWith(kapakOdak: odak));
      });
      return;
    }
    SecilenFoto? foto;
    try {
      foto = await maisonFotoSec(islem, FotoBoyu.kapak);
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
    final Offset? odak = await maisonOdakSec(
      context,
      resim: MemoryImage(secilen.baytlar),
      oran: 390 / 274,
    );
    if (odak == null || !mounted) {
      return;
    }
    await _calistir('kapak', (SupabaseClient i, VitrinVerisi v) async {
      final String url = await maisonFotoYukle(i, kova: 'salon', klasor: widget.salon.id, ad: 'kapak', foto: secilen);
      await _salonaYaz(i, <String, dynamic>{'kapak_url': url, 'kapak_odak_x': odak.dx, 'kapak_odak_y': odak.dy});
      await maisonFotoSil(i, eski);
      _salonuGuncelle(v.salon.copyWith(kapakUrl: url, kapakOdak: odak));
    });
  }

  // ---------------------------------------------------------------- Logo

  Future<void> _logoIslemi() async {
    if (!_duzenlemeBaslasin()) {
      return;
    }
    final VitrinVerisi v = _veri!;
    final String? eski = v.salon.logoUrl;
    final FotoIslemi? islem = await maisonFotoIslemiSor(context, baslik: dl('Logo', 'Logo'), kaldirilabilir: eski != null);
    if (islem == null || islem == FotoIslemi.odak || !mounted) {
      return;
    }
    if (islem == FotoIslemi.kaldir) {
      await _calistir('logo', (SupabaseClient i, VitrinVerisi v) async {
        await _salonaYaz(i, <String, dynamic>{'logo_url': null});
        await maisonFotoSil(i, eski);
        _salonuGuncelle(v.salon.copyWith(logoSil: true));
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
    await _calistir('logo', (SupabaseClient i, VitrinVerisi v) async {
      final String url = await maisonFotoYukle(i, kova: 'salon', klasor: widget.salon.id, ad: 'logo', foto: secilen);
      await _salonaYaz(i, <String, dynamic>{'logo_url': url});
      await maisonFotoSil(i, eski);
      _salonuGuncelle(v.salon.copyWith(logoUrl: url));
    });
  }

  // ---------------------------------------------------------------- Galeri

  Future<void> _galeriyeEkle() async {
    if (!_duzenlemeBaslasin()) {
      return;
    }
    final VitrinVerisi v = _veri!;
    final int bosYer = _galeriSiniri - v.galeri.length;
    if (bosYer <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dl('Galeri dolu: en çok $_galeriSiniri fotoğraf. Yer açmak için eski bir fotoğrafı sil.', 'The gallery is full: at most $_galeriSiniri photos. Delete an old photo to make room.')),
        ),
      );
      return;
    }
    List<SecilenFoto> fotolar;
    try {
      fotolar = await maisonFotolarSec(FotoBoyu.galeri, sinir: math.min(10, bosYer));
    } catch (hata) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
      }
      return;
    }
    if (fotolar.isEmpty || !mounted) {
      return;
    }
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    await _calistir('galeri', (SupabaseClient i, VitrinVerisi v) async {
      if (mounted) {
        setState(() {
          _galeriBiten = 0;
          _galeriToplam = fotolar.length;
        });
      }
      int eklenen = 0;
      for (final SecilenFoto foto in fotolar) {
        final String url = await maisonFotoYukle(
          i,
          kova: 'salon',
          klasor: '${widget.salon.id}/galeri',
          ad: 'foto',
          foto: foto,
        );
        final Map<String, dynamic> satir;
        try {
          satir = await i
              .from('galeri')
              .insert(<String, dynamic>{
                'salon_id': widget.salon.id,
                'url': url,
                'kategori': 'sac',
                'herkese_acik': true,
              })
              .select('id, url, aciklama, kategori')
              .single();
        } catch (_) {
          // Kaydı tutulamayan dosya depoda sahipsiz kalmasın.
          await maisonFotoSil(i, url);
          rethrow;
        }
        eklenen++;
        final VitrinFotografi yeni = VitrinFotografi.json(satir);
        if (mounted) {
          final VitrinVerisi? simdiki = _veri;
          setState(() {
            _galeriBiten = eklenen;
            if (simdiki != null) {
              _veri = simdiki.copyWith(galeri: <VitrinFotografi>[yeni, ...simdiki.galeri]);
            }
          });
        }
      }
      mesaj.showSnackBar(
        SnackBar(content: Text(eklenen == 1 ? dl('Fotoğraf galeriye eklendi.', 'Photo added to the gallery.') : dl('$eklenen fotoğraf galeriye eklendi.', '$eklenen photos added to the gallery.'))),
      );
    });
  }

  Future<void> _fotoDuzenle(VitrinFotografi foto) async {
    if (!_duzenlemeBaslasin()) {
      return;
    }
    final VitrinVerisi v = _veri!;
    final MaisonRenkler r = MaisonRenkler.of(context);
    final _FotoKarari? karar = await showModalBottomSheet<_FotoKarari>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => _FotoDuzenleyici(foto: foto, filtre: v.salon.ayar.filtre),
    );
    if (karar == null || !mounted) {
      return;
    }
    if (karar.sil) {
      final bool? eminim = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          backgroundColor: r.kart,
          title: Text(dl('Fotoğraf silinsin mi?', 'Delete this photo?'), style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
          content: Text(
            dl('Fotoğraf vitrinden ve depodan kalıcı olarak silinir.', 'The photo is permanently removed from the showcase and storage.'),
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(dl('Vazgeç', 'Cancel'))),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(dl('Sil', 'Delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      );
      if (eminim != true || !mounted) {
        return;
      }
      await _calistir('galeri', (SupabaseClient i, VitrinVerisi v) async {
        await i.from('galeri').delete().eq('id', foto.id);
        await maisonFotoSil(i, foto.url);
        if (mounted) {
          final VitrinVerisi? simdiki = _veri;
          if (simdiki != null) {
            setState(() {
              _veri = simdiki.copyWith(
                galeri: simdiki.galeri.where((VitrinFotografi f) => f.id != foto.id).toList(),
              );
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dl('Fotoğraf silindi.', 'Photo deleted.'))));
        }
      });
      return;
    }
    await _calistir('galeri', (SupabaseClient i, VitrinVerisi v) async {
      final String? aciklama = karar.aciklama.trim().isEmpty ? null : karar.aciklama.trim();
      await i
          .from('galeri')
          .update(<String, dynamic>{'aciklama': aciklama, 'kategori': karar.kategori})
          .eq('id', foto.id);
      if (mounted) {
        final VitrinVerisi? simdiki = _veri;
        if (simdiki != null) {
          setState(() {
            _veri = simdiki.copyWith(
              galeri: simdiki.galeri
                  .map((VitrinFotografi f) => f.id == foto.id
                      ? VitrinFotografi(id: f.id, url: f.url, aciklama: aciklama, kategori: karar.kategori)
                      : f)
                  .toList(),
            );
          });
        }
      }
    });
  }

  // ---------------------------------------------------------------- Filtre ve tema

  /// Filtre ve tema: önce ekranda değişir, kaydedilemezse eski hâline döner.
  Future<void> _ayariKaydet(VitrinAyari yeni) async {
    await _calistir('ayar', (SupabaseClient i, VitrinVerisi v) async {
      final VitrinAyari eski = v.salon.ayar;
      _salonuGuncelle(v.salon.copyWith(ayar: yeni));
      try {
        await _salonaYaz(i, <String, dynamic>{'vitrin': yeni.json()});
      } catch (_) {
        _salonuGuncelle(v.salon.copyWith(ayar: eski));
        rethrow;
      }
    });
  }

  Future<void> _yayinla() async {
    await _calistir('yayin', (SupabaseClient i, VitrinVerisi v) async {
      await _salonaYaz(i, <String, dynamic>{'yayinda': true});
      _salonuGuncelle(v.salon.copyWith(yayinda: true));
      widget.salonDegisti();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dl('Vitrinin yayında; müşteriler Keşfet\'te görür.', 'Your showcase is live; customers can see it in Discover.'))),
        );
      }
    });
  }

  void _tamEkranOnizleme() {
    final VitrinVerisi? v = _veri;
    if (v == null) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MaisonVitrinTemasi(
          ayar: v.salon.ayar,
          child: Builder(
            builder: (BuildContext context) {
              final MaisonRenkler r = MaisonRenkler.of(context);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: maisonSistemCubugu(v.salon.ayar.palet),
                child: Scaffold(
                  backgroundColor: r.zemin,
                  body: MaisonVitrinGorunumu(
                    salon: v.salon,
                    veri: v,
                    onRandevu: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(dl('Müşteriler bu düğmeyle randevu alacak.', 'Customers will book with this button.'))),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Ekran

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonTercih.proPaleti),
      child: Scaffold(
        backgroundColor: r.zemin,
        body: SafeArea(
          child: FutureBuilder<VitrinVerisi>(
            future: _ilkYukleme,
            builder: (BuildContext context, AsyncSnapshot<VitrinVerisi> durum) {
              final VitrinVerisi? v = _veri;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: <Widget>[
                  _ustSatir(r, v),
                  const SizedBox(height: 16),
                  if (v == null && durum.hasError && durum.connectionState == ConnectionState.done)
                    MaisonHataKutusu(maisonHataMetni(durum.error!), tekrar: _tekrarDene)
                  else if (v == null)
                    const MaisonYukleniyor()
                  else
                    ..._bolumler(r, v),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _ustSatir(MaisonRenkler r, VitrinVerisi? v) {
    final bool yayinda = v?.salon.yayinda ?? widget.salon.yayinda;
    return Row(
      children: <Widget>[
        MaisonYuvarlakDugme(
          ikon: Icons.arrow_back,
          etiket: dl('Geri', 'Back'),
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            dl('Vitrin Stüdyosu', 'Showcase Studio'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: maisonBaslik(28, renk: r.yazi, yukseklik: 1.05),
          ),
        ),
        if (v != null && !yayinda && _duzenleyebilir)
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: _islem == null ? _yayinla : null,
              child: Text(dl('Yayınla', 'Publish')),
            ),
          )
        else if (v != null && yayinda)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: r.vurguYumusak,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.check, size: 16, color: r.vurgu),
                const SizedBox(width: 6),
                Text(dl('Yayında', 'Live'), style: maisonGovde(13, renk: r.vurgu, kalinlik: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _bolumler(MaisonRenkler r, VitrinVerisi v) {
    final VitrinSalonu s = v.salon;
    final String? ornekFoto = s.kapakUrl ?? (v.galeri.isNotEmpty ? v.galeri.first.url : null);
    return <Widget>[
      _onizleme(r, v),
      const SizedBox(height: 8),
      Text(
        dl('Müşterinin gördüğü önizleme · tam ekran için dokun', 'Preview of what customers see · tap for full screen'),
        textAlign: TextAlign.center,
        style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3),
      ),
      if (!_duzenleyebilir) ...<Widget>[
        const SizedBox(height: 14),
        Text(
          dl('Vitrini yalnız salon sahibi düzenleyebilir.', 'Only the salon owner can edit the showcase.'),
          textAlign: TextAlign.center,
          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
        ),
      ],
      const SizedBox(height: 22),
      _baslik(dl('KAPAK FOTOĞRAFI', 'COVER PHOTO')),
      const SizedBox(height: 10),
      _kapakKarti(r, s),
      const SizedBox(height: 22),
      _baslik(dl('LOGO', 'LOGO')),
      const SizedBox(height: 10),
      _logoSatiri(r, s),
      const SizedBox(height: 22),
      _baslik(dl('GALERİ DUVARI · ${v.galeri.length} FOTOĞRAF', 'GALLERY WALL · ${v.galeri.length} PHOTO${v.galeri.length == 1 ? '' : 'S'}')),
      const SizedBox(height: 10),
      if (_islem == 'galeri' && _galeriToplam > 0) ...<Widget>[
        LinearProgressIndicator(
          value: _galeriToplam == 0 ? null : _galeriBiten / _galeriToplam,
          color: r.vurgu,
          backgroundColor: r.cizgi,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 6),
        Text(
          dl('$_galeriBiten / $_galeriToplam fotoğraf yüklendi…', '$_galeriBiten / $_galeriToplam photos uploaded…'),
          style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3),
        ),
        const SizedBox(height: 10),
      ],
      _galeriIzgarasi(r, v),
      const SizedBox(height: 22),
      _baslik(dl('VİTRİN FİLTRESİ', 'SHOWCASE FILTER')),
      const SizedBox(height: 4),
      Text(
        ornekFoto == null
            ? dl('Seçtiğin renk ayarı kapak ve galerideki bütün fotoğraflara birlikte uygulanır. '
                'Farkı görmek için önce bir kapak ya da galeri fotoğrafı ekle.', 'The colour setting you choose applies to the cover and every gallery photo. '
                    'Add a cover or gallery photo first to see the difference.')
            : dl('Seçtiğin renk ayarı kapak ve galerideki bütün fotoğraflara birlikte uygulanır.', 'The colour setting you choose applies to the cover and every gallery photo.'),
        style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
      ),
      const SizedBox(height: 12),
      _filtreSecici(r, s, ornekFoto),
      const SizedBox(height: 22),
      _baslik(dl('VİTRİN TEMASI', 'SHOWCASE THEME')),
      const SizedBox(height: 12),
      _temaSecici(r, s),
      const SizedBox(height: 14),
      _vurguSecici(r, s),
      const SizedBox(height: 22),
      Text(
        dl('Değişiklikler hemen kaydedilir. Müşteriler vitrini salon yayındayken görür.', 'Changes are saved right away. Customers see the showcase while the salon is live.'),
        textAlign: TextAlign.center,
        style: maisonGovde(12, renk: r.soluk, yukseklik: 1.4),
      ),
    ];
  }

  Widget _baslik(String metin) => MaisonUstBaslik(metin);

  Widget _onizleme(MaisonRenkler r, VitrinVerisi v) {
    // Önizleme 390 × 780 noktalık bir telefon ekranı gibi çizilir, sonra çerçeveye sığdırılır.
    final MediaQueryData ortam = MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 24),
      viewPadding: const EdgeInsets.only(top: 24),
      viewInsets: EdgeInsets.zero,
      size: const Size(390, 780),
    );
    return Semantics(
      button: true,
      label: dl('Vitrini tam ekran önizle', 'Preview showcase full screen'),
      child: GestureDetector(
        onTap: _tamEkranOnizleme,
        child: Container(
          height: _onizlemeYukseklik + 28,
          decoration: BoxDecoration(
            color: Color.lerp(r.zemin, r.cizgi, 0.6),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Container(
            width: _onizlemeGenislik,
            height: _onizlemeYukseklik,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: v.salon.ayar.palet.zemin,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF1C1B19), width: 4),
            ),
            child: IgnorePointer(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 390,
                  height: 780,
                  child: MediaQuery(
                    data: ortam,
                    child: MaisonVitrinTemasi(
                      ayar: v.salon.ayar,
                      child: Builder(
                        builder: (BuildContext context) => Material(
                          color: MaisonRenkler.of(context).zemin,
                          child: MaisonVitrinGorunumu(salon: v.salon, veri: v, onizleme: true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kapakKarti(MaisonRenkler r, VitrinSalonu s) {
    final bool calisiyor = _islem == 'kapak';
    return Material(
      color: r.kart,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _islem == null ? _kapakIslemi : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 390 / 274,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  MaisonKapak(yukseklik: 274, url: s.kapakUrl, odak: s.kapakOdak, filtre: s.ayar.filtre),
                  if (calisiyor)
                    ColoredBox(
                      color: r.zemin.withValues(alpha: 0.55),
                      child: const MaisonYukleniyor(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      s.kapakUrl == null
                          ? dl('Kapak fotoğrafı ekle: salonunun en iyi görünen köşesi.', 'Add a cover photo: the best-looking corner of your salon.')
                          : dl('Değiştirmek ya da görünen kısmı ayarlamak için dokun.', 'Tap to change it or adjust the visible area.'),
                      style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
                    ),
                  ),
                  Icon(Icons.photo_camera_outlined, color: r.vurgu, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoSatiri(MaisonRenkler r, VitrinSalonu s) {
    final String? logo = s.logoUrl;
    return Material(
      color: r.kart,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _islem == null ? _logoIslemi : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: r.zemin,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: r.vurgu, width: 1.5),
                ),
                child: _islem == 'logo'
                    ? const MaisonYukleniyor()
                    : logo != null
                        ? MaisonFoto(url: logo, zemin: r.zemin)
                        : Center(
                            child: Text(
                              s.basHarfler,
                              style: maisonBaslik(24, renk: r.vurgu, kalinlik: FontWeight.w600, yukseklik: 1.0),
                            ),
                          ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  logo == null
                      ? dl('Logo ekle. Kare bir logo en iyi görünür; yoksa salonun baş harfleri kullanılır.', 'Add a logo. A square logo looks best; otherwise the salon\'s initials are used.')
                      : dl('Logoyu değiştirmek ya da kaldırmak için dokun.', 'Tap to change or remove the logo.'),
                  style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galeriIzgarasi(MaisonRenkler r, VitrinVerisi v) {
    final List<Widget> kutular = <Widget>[
      Semantics(
        button: true,
        label: dl('Galeriye fotoğraf ekle', 'Add photos to the gallery'),
        child: Material(
          color: r.kart,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _islem == null ? _galeriyeEkle : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.add_photo_alternate_outlined, color: r.vurgu, size: 26),
                const SizedBox(height: 6),
                Text(dl('Ekle', 'Add'), style: maisonGovde(13, renk: r.yazi, kalinlik: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
      for (final VitrinFotografi f in v.galeri)
        GestureDetector(
          onTap: _islem == null ? () => _fotoDuzenle(f) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: MaisonFoto(url: f.url, filtre: v.salon.ayar.filtre, zemin: r.kart, etiket: f.aciklama),
          ),
        ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      padding: EdgeInsets.zero,
      children: kutular,
    );
  }

  /// Fotoğraf yokken filtre örneği boş kapağa uygulanır.
  Widget _suzgecli(VitrinFiltresi f, Widget cocuk) {
    final ColorFilter? suzgec = f.suzgec;
    return suzgec == null ? cocuk : ColorFiltered(colorFilter: suzgec, child: cocuk);
  }

  Widget _filtreSecici(MaisonRenkler r, VitrinSalonu s, String? ornekFoto) {
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: VitrinFiltresi.values.length,
        separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int i) {
          final VitrinFiltresi f = VitrinFiltresi.values[i];
          final bool secili = f == s.ayar.filtre;
          return Semantics(
            button: true,
            selected: secili,
            label: dl('${f.ad} filtresi', '${f.ad} filter'),
            child: GestureDetector(
              onTap: _islem == null && !secili ? () => _ayariKaydet(s.ayar.copyWith(filtre: f)) : null,
              child: SizedBox(
                width: 86,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 86,
                      height: 86,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: secili ? r.vurgu : r.cizgi, width: secili ? 2 : 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ornekFoto == null
                            ? _suzgecli(f, const MaisonKapak(yukseklik: 80))
                            : MaisonFoto(url: ornekFoto, filtre: f, zemin: r.kart),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      f.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(
                        12,
                        renk: secili ? r.yazi : r.soluk,
                        kalinlik: secili ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _temaSecici(MaisonRenkler r, VitrinSalonu s) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (final MaisonPalet p in MaisonPalet.tumu)
          Semantics(
            button: true,
            selected: p.kimlik == s.ayar.paletKimligi,
            label: dl('${p.ad} teması', '${p.ad} theme'),
            child: GestureDetector(
              onTap: _islem == null && p.kimlik != s.ayar.paletKimligi
                  ? () => _ayariKaydet(s.ayar.copyWith(paletKimligi: p.kimlik, vurgu: 0))
                  : null,
              child: SizedBox(
                width: 60,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: p.kimlik == s.ayar.paletKimligi ? r.vurgu : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.zemin,
                          border: Border.all(color: r.cizgi),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: p.vurgu),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: maisonGovde(11, renk: r.soluk, kalinlik: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _vurguSecici(MaisonRenkler r, VitrinSalonu s) {
    final List<MaisonVurgu> secenekler = s.ayar.palet.vurgular;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 8,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(dl('Vurgu rengi', 'Accent colour'), style: maisonGovde(13, renk: r.soluk, kalinlik: FontWeight.w500)),
        ),
        for (int i = 0; i < secenekler.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Semantics(
              button: true,
              selected: s.ayar.vurguRengi == secenekler[i].renk,
              label: secenekler[i].ad,
              child: GestureDetector(
                onTap: _islem == null && s.ayar.vurguRengi != secenekler[i].renk
                    ? () => _ayariKaydet(s.ayar.copyWith(vurgu: i))
                    : null,
                child: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: s.ayar.vurguRengi == secenekler[i].renk ? r.vurgu : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: secenekler[i].renk),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Galeri fotoğrafı düzenleme sayfasının sonucu.
class _FotoKarari {
  const _FotoKarari({this.sil = false, this.aciklama = '', this.kategori = 'sac'});

  final bool sil;
  final String aciklama;
  final String kategori;
}

/// Galeri fotoğrafı için açıklama ve kategori; ya da silme.
class _FotoDuzenleyici extends StatefulWidget {
  const _FotoDuzenleyici({required this.foto, required this.filtre});

  final VitrinFotografi foto;
  final VitrinFiltresi filtre;

  @override
  State<_FotoDuzenleyici> createState() => _FotoDuzenleyiciState();
}

class _FotoDuzenleyiciState extends State<_FotoDuzenleyici> {
  late final TextEditingController _aciklama = TextEditingController(text: widget.foto.aciklama ?? '');
  late String _kategori = _kategoriler.containsKey(widget.foto.kategori) ? widget.foto.kategori : 'sac';

  @override
  void dispose() {
    _aciklama.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Color hataRengi = Theme.of(context).colorScheme.error;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: MaisonFoto(url: widget.foto.url, filtre: widget.filtre, zemin: r.zemin),
                ),
              ),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: dl('AÇIKLAMA', 'CAPTION'),
                kontrol: _aciklama,
                ipucu: dl('Ör. Usta Mert · Fade', 'E.g. Mert · Fade'),
                enFazla: 300,
                buyukHarf: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              MaisonUstBaslik(dl('KATEGORİ', 'CATEGORY')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final MapEntry<String, String> k in _kategoriler.entries)
                    ChoiceChip(
                      label: Text(k.value),
                      selected: _kategori == k.key,
                      onSelected: (bool _) => setState(() => _kategori = k.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(const _FotoKarari(sil: true)),
                    icon: Icon(Icons.delete_outline, color: hataRengi),
                    label: Text(dl('Sil', 'Delete'), style: maisonGovde(14, renk: hataRengi, kalinlik: FontWeight.w600)),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _FotoKarari(aciklama: _aciklama.text, kategori: _kategori),
                      ),
                      child: Text(dl('Kaydet', 'Save')),
                    ),
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
