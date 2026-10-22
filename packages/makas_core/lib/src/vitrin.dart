import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import 'bilesenler.dart';
import 'dil.dart';
import 'foto.dart';
import 'isletme.dart';
import 'oturum.dart';
import 'renkler.dart';
import 'tarih.dart';
import 'tema.dart';
import 'vitrin_ayari.dart';

/// Vitrinde gösterilen salon bilgisi.
@immutable
class VitrinSalonu {
  const VitrinSalonu({
    required this.id,
    required this.ad,
    this.ilce,
    this.sehir,
    this.adres,
    this.telefon,
    this.aciklama,
    this.logoUrl,
    this.kapakUrl,
    this.kapakOdak = const Offset(0.5, 0.5),
    this.ayar = const VitrinAyari(),
    this.dogrulandi = false,
    this.ortalama,
    this.yorumAdet = 0,
    this.paraBirimi = 'TRY',
    this.yayinda = true,
    this.ucretsizIptalDk = 180,
  });

  /// `salonlar` satırından (ve varsa `salon_puanlari` satırından) okur.
  factory VitrinSalonu.json(Map<String, dynamic> m, {Map<String, dynamic>? puan}) {
    final Object? ortalama = puan != null ? puan['ortalama'] : m['ortalama'];
    final Object? adet = puan != null ? puan['adet'] : m['yorum_adet'];
    return VitrinSalonu(
      id: m['id'] as String,
      ad: (m['ad'] as String?) ?? '',
      ilce: m['ilce'] as String?,
      sehir: m['sehir'] as String?,
      adres: m['adres'] as String?,
      telefon: m['telefon'] as String?,
      aciklama: m['aciklama'] as String?,
      logoUrl: m['logo_url'] as String?,
      kapakUrl: m['kapak_url'] as String?,
      kapakOdak: Offset(_oran(m['kapak_odak_x']), _oran(m['kapak_odak_y'])),
      ayar: VitrinAyari.json(m['vitrin']),
      dogrulandi: m['dogrulandi'] == true,
      ortalama: ortalama is num ? ortalama.toDouble() : null,
      yorumAdet: adet is num ? adet.toInt() : 0,
      paraBirimi: (m['para_birimi'] as String?) ?? 'TRY',
      yayinda: m['yayinda'] != false,
      ucretsizIptalDk: (m['ucretsiz_iptal_dk'] as num?)?.toInt() ?? 180,
    );
  }

  static double _oran(Object? deger) {
    if (deger is num) {
      return deger.toDouble().clamp(0.0, 1.0).toDouble();
    }
    return 0.5;
  }

  final String id;
  final String ad;
  final String? ilce;
  final String? sehir;
  final String? adres;
  final String? telefon;
  final String? aciklama;
  final String? logoUrl;
  final String? kapakUrl;
  final Offset kapakOdak;
  final VitrinAyari ayar;
  final bool dogrulandi;
  final double? ortalama;
  final int yorumAdet;
  final String paraBirimi;
  final bool yayinda;

  /// Müşteri randevusunu bu kadar dakika öncesine kadar ücretsiz iptal eder.
  final int ucretsizIptalDk;

  /// "Riva, İstanbul"
  String get yer => <String?>[ilce, sehir]
      .whereType<String>()
      .where((String s) => s.trim().isNotEmpty)
      .join(', ');

  /// "4,9" ya da "Yeni"
  String get puanMetni {
    final double? o = ortalama;
    if (o == null) {
      return dl('Yeni', 'New');
    }
    return maisonOndalik(o);
  }

  /// Logo yokken gösterilen iki harf.
  String get basHarfler {
    final List<String> kelimeler =
        ad.trim().split(RegExp(r'\s+')).where((String k) => k.isNotEmpty).toList();
    if (kelimeler.isEmpty) {
      return 'M';
    }
    final String ilk = kelimeler.first.substring(0, 1);
    final String ikinci = kelimeler.length > 1 ? kelimeler[1].substring(0, 1) : '';
    return (ilk + ikinci).toUpperCase();
  }

  VitrinSalonu copyWith({
    String? kapakUrl,
    bool kapakSil = false,
    Offset? kapakOdak,
    String? logoUrl,
    bool logoSil = false,
    VitrinAyari? ayar,
    bool? yayinda,
  }) {
    return VitrinSalonu(
      id: id,
      ad: ad,
      ilce: ilce,
      sehir: sehir,
      adres: adres,
      telefon: telefon,
      aciklama: aciklama,
      logoUrl: logoSil ? null : (logoUrl ?? this.logoUrl),
      kapakUrl: kapakSil ? null : (kapakUrl ?? this.kapakUrl),
      kapakOdak: kapakOdak ?? this.kapakOdak,
      ayar: ayar ?? this.ayar,
      dogrulandi: dogrulandi,
      ortalama: ortalama,
      yorumAdet: yorumAdet,
      paraBirimi: paraBirimi,
      yayinda: yayinda ?? this.yayinda,
      ucretsizIptalDk: ucretsizIptalDk,
    );
  }
}

/// Hizmet menüsünde bir kalem.
@immutable
class VitrinHizmeti {
  const VitrinHizmeti({
    this.id = '',
    required this.ad,
    required this.sureDk,
    required this.fiyat,
    this.aciklama,
    this.kategori = HizmetKategorisi.sac,
  });

  factory VitrinHizmeti.json(Map<String, dynamic> m) {
    return VitrinHizmeti(
      id: (m['id'] as String?) ?? '',
      ad: (m['ad'] as String?) ?? '',
      sureDk: (m['sure_dk'] as num?)?.toInt() ?? 0,
      fiyat: (m['fiyat'] as num?)?.toDouble() ?? 0.0,
      aciklama: m['aciklama'] as String?,
      kategori: HizmetKategorisi.kimliktenBul(m['kategori']),
    );
  }

  /// Randevu alırken gönderilen kimlik.
  final String id;
  final String ad;
  final int sureDk;
  final double fiyat;
  final String? aciklama;
  final HizmetKategorisi kategori;
}

/// Galeri duvarında bir fotoğraf.
@immutable
class VitrinFotografi {
  const VitrinFotografi({required this.id, required this.url, this.aciklama, this.kategori = 'sac'});

  factory VitrinFotografi.json(Map<String, dynamic> m) {
    return VitrinFotografi(
      id: m['id'] as String,
      url: (m['url'] as String?) ?? '',
      aciklama: m['aciklama'] as String?,
      kategori: (m['kategori'] as String?) ?? 'sac',
    );
  }

  final String id;
  final String url;
  final String? aciklama;
  final String kategori;

  VitrinFotografi copyWith({String? aciklama, String? kategori}) {
    return VitrinFotografi(
      id: id,
      url: url,
      aciklama: aciklama ?? this.aciklama,
      kategori: kategori ?? this.kategori,
    );
  }
}

/// Ekipte bir usta.
@immutable
class VitrinUstasi {
  const VitrinUstasi({
    required this.id,
    required this.ad,
    this.unvan,
    this.fotoUrl,
    this.uzmanlik = const <String>[],
  });

  factory VitrinUstasi.json(Map<String, dynamic> m) {
    final Object? uzmanlik = m['uzmanlik'];
    return VitrinUstasi(
      id: m['id'] as String,
      ad: (m['ad'] as String?) ?? '',
      unvan: m['unvan'] as String?,
      fotoUrl: m['foto_url'] as String?,
      uzmanlik: uzmanlik is List ? uzmanlik.whereType<String>().toList() : const <String>[],
    );
  }

  final String id;
  final String ad;
  final String? unvan;
  final String? fotoUrl;
  final List<String> uzmanlik;

  String get basHarfler {
    final List<String> kelimeler =
        ad.trim().split(RegExp(r'\s+')).where((String k) => k.isNotEmpty).toList();
    if (kelimeler.isEmpty) {
      return 'U';
    }
    final String ilk = kelimeler.first.substring(0, 1);
    final String son = kelimeler.length > 1 ? kelimeler.last.substring(0, 1) : '';
    return (ilk + son).toUpperCase();
  }
}

/// Doğrulanmış bir yorum (yalnız tamamlanan randevudan sonra yazılır).
@immutable
class VitrinYorumu {
  const VitrinYorumu({
    required this.id,
    required this.gorunenAd,
    required this.puan,
    required this.olusturuldu,
    this.metin,
    this.yanit,
  });

  factory VitrinYorumu.json(Map<String, dynamic> m) {
    return VitrinYorumu(
      id: m['id'] as String,
      gorunenAd: (m['gorunen_ad'] as String?) ?? dl('Müşteri', 'Customer'),
      puan: (m['puan'] as num?)?.toInt() ?? 5,
      metin: m['metin'] as String?,
      yanit: m['yanit'] as String?,
      olusturuldu: DateTime.tryParse((m['olusturuldu'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  final String id;
  final String gorunenAd;
  final int puan;
  final String? metin;
  final String? yanit;
  final DateTime olusturuldu;
}

/// Vitrinin bütün verisi.
@immutable
class VitrinVerisi {
  const VitrinVerisi({
    required this.salon,
    this.hizmetler = const <VitrinHizmeti>[],
    this.galeri = const <VitrinFotografi>[],
    this.ekip = const <VitrinUstasi>[],
    this.yorumlar = const <VitrinYorumu>[],
    this.saatler,
  });

  final VitrinSalonu salon;
  final List<VitrinHizmeti> hizmetler;
  final List<VitrinFotografi> galeri;
  final List<VitrinUstasi> ekip;
  final List<VitrinYorumu> yorumlar;

  /// Salonun haftalık açık saatleri; sunucuda henüz yoksa null.
  final SalonSaatleri? saatler;

  VitrinVerisi copyWith({VitrinSalonu? salon, List<VitrinFotografi>? galeri}) {
    return VitrinVerisi(
      salon: salon ?? this.salon,
      hizmetler: hizmetler,
      galeri: galeri ?? this.galeri,
      ekip: ekip,
      yorumlar: yorumlar,
      saatler: saatler,
    );
  }

  /// Salonun vitrinini sunucudan tek seferde (altı sorgu birlikte) okur.
  static Future<VitrinVerisi> yukle(SupabaseClient istemci, String salonId) async {
    final List<Object?> sonuc = await Future.wait<Object?>(<Future<Object?>>[
      istemci
          .from('salonlar')
          .select('id, ad, ilce, sehir, adres, telefon, aciklama, logo_url, kapak_url, '
              'kapak_odak_x, kapak_odak_y, vitrin, dogrulandi, para_birimi, yayinda, ucretsiz_iptal_dk')
          .eq('id', salonId)
          .single(),
      istemci.from('salon_puanlari').select('ortalama, adet').eq('salon_id', salonId).maybeSingle(),
      istemci
          .from('hizmetler')
          .select('id, ad, sure_dk, fiyat, aciklama, kategori')
          .eq('salon_id', salonId)
          .eq('aktif', true)
          .order('sira', ascending: true),
      istemci
          .from('galeri')
          .select('id, url, aciklama, kategori')
          .eq('salon_id', salonId)
          .eq('herkese_acik', true)
          .order('olusturuldu', ascending: false)
          .limit(60),
      istemci
          .from('ustalar')
          .select('id, ad, unvan, foto_url, uzmanlik')
          .eq('salon_id', salonId)
          .eq('aktif', true)
          .order('sira', ascending: true),
      istemci
          .from('yorumlar')
          .select('id, gorunen_ad, puan, metin, yanit, olusturuldu')
          .eq('salon_id', salonId)
          .eq('gizli', false)
          .order('olusturuldu', ascending: false)
          .limit(30),
      // 20. adımın SQL kodu çalıştırılmadıysa saatler gösterilmez; vitrin yine açılır.
      istemci
          .rpc('salon_saatleri', params: <String, dynamic>{'p_salon': salonId})
          .then<Object?>((Object? sonuc) => sonuc, onError: (Object _) => null),
    ]);
    final Object? salonSatiri = sonuc[0];
    final Object? puanSatiri = sonuc[1];
    if (salonSatiri is! Map<String, dynamic>) {
      throw MaisonHata(dl('Salon bulunamadı.', 'Salon not found.'));
    }
    return VitrinVerisi(
      salon: VitrinSalonu.json(
        salonSatiri,
        puan: puanSatiri is Map<String, dynamic> ? puanSatiri : const <String, dynamic>{},
      ),
      hizmetler: _satirlar(sonuc[2]).map(VitrinHizmeti.json).toList(),
      galeri: _satirlar(sonuc[3]).map(VitrinFotografi.json).where((VitrinFotografi f) => f.url.isNotEmpty).toList(),
      ekip: _satirlar(sonuc[4]).map(VitrinUstasi.json).toList(),
      yorumlar: _satirlar(sonuc[5]).map(VitrinYorumu.json).toList(),
      saatler: sonuc[6] is Map ? SalonSaatleri.json(sonuc[6]) : null,
    );
  }

  static List<Map<String, dynamic>> _satirlar(Object? liste) {
    if (liste is! List) {
      return <Map<String, dynamic>>[];
    }
    return liste.whereType<Map<String, dynamic>>().toList();
  }
}

/// Salonun yerini Google Haritalar'da açar (ad, adres, ilçe, şehir ile arar). Açılamazsa false.
Future<bool> maisonYolTarifiAc(VitrinSalonu s) async {
  final String sorgu = <String?>[s.ad, s.adres, s.ilce, s.sehir]
      .whereType<String>()
      .where((String p) => p.trim().isNotEmpty)
      .join(', ');
  try {
    return await launchUrl(
      Uri.https('www.google.com', '/maps/search/', <String, String>{'api': '1', 'query': sorgu}),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

/// Telefon uygulamasında numarayı açar. Açılamazsa false.
Future<bool> maisonTelefonAc(String telefon) async {
  final String rakam = telefon.replaceAll(RegExp(r'[^0-9+]'), '');
  if (rakam.length < 7) {
    return false;
  }
  try {
    return await launchUrl(Uri(scheme: 'tel', path: rakam), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Telefonu WhatsApp için uluslararası biçime çevirir (0532… → 90532…). Geçersizse null.
String? maisonUluslararasiTelefon(String? telefon) {
  if (telefon == null) {
    return null;
  }
  String rakam = telefon.replaceAll(RegExp(r'[^0-9]'), '');
  if (rakam.startsWith('00')) {
    rakam = rakam.substring(2);
  } else if (rakam.length == 11 && rakam.startsWith('0')) {
    rakam = '9$rakam';
  } else if (rakam.length == 10 && rakam.startsWith('5')) {
    rakam = '90$rakam';
  }
  return rakam.length >= 10 ? rakam : null;
}

/// Alt ağaca salonun vitrin temasını (palet ve vurgu rengi) uygular.
class MaisonVitrinTemasi extends StatelessWidget {
  const MaisonVitrinTemasi({super.key, required this.ayar, required this.child});

  final VitrinAyari ayar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: maisonTemasi(ayar.palet, vurgu: ayar.vurguRengi), child: child);
  }
}

/// Salon vitrini ekranı: kapak, logo, eylemler ve Hizmetler · Galeri · Ekip · Yorumlar.
///
/// [salon] hemen gösterilir (ör. keşfet kartından gelen özet); ayrıntılar sunucudan yüklenir.
class MaisonVitrinEkrani extends StatefulWidget {
  const MaisonVitrinEkrani({
    super.key,
    required this.salon,
    this.kahramanEtiketi,
    this.onRandevu,
  });

  final VitrinSalonu salon;

  /// Karttan vitrine geçerken kapağın büyüyerek gelmesi için ortak etiket.
  final String? kahramanEtiketi;

  final VoidCallback? onRandevu;

  @override
  State<MaisonVitrinEkrani> createState() => _MaisonVitrinEkraniState();
}

class _MaisonVitrinEkraniState extends State<MaisonVitrinEkrani> {
  Future<VitrinVerisi>? _gelecek;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gelecek ??= _yukle();
  }

  Future<VitrinVerisi> _yukle() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final SupabaseClient istemci = await oturum.istemciGerekli();
    return VitrinVerisi.yukle(istemci, widget.salon.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VitrinVerisi>(
      future: _gelecek,
      builder: (BuildContext context, AsyncSnapshot<VitrinVerisi> durum) {
        final VitrinVerisi? veri = durum.data;
        final VitrinSalonu salon = veri?.salon ?? widget.salon;
        final Object? hata = durum.error;
        return MaisonVitrinTemasi(
          ayar: salon.ayar,
          child: Builder(
            builder: (BuildContext context) {
              final MaisonRenkler r = MaisonRenkler.of(context);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: maisonSistemCubugu(salon.ayar.palet),
                child: Scaffold(
                  backgroundColor: r.zemin,
                  body: MaisonVitrinGorunumu(
                    salon: salon,
                    veri: veri,
                    hata: hata == null ? null : maisonHataMetni(hata),
                    onTekrar: () => setState(() => _gelecek = _yukle()),
                    kahramanEtiketi: widget.kahramanEtiketi,
                    onRandevu: widget.onRandevu,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Vitrinin kendisi (veri dışarıdan gelir). Makas Pro'da önizleme olarak da kullanılır.
class MaisonVitrinGorunumu extends StatefulWidget {
  const MaisonVitrinGorunumu({
    super.key,
    required this.salon,
    this.veri,
    this.hata,
    this.onTekrar,
    this.kahramanEtiketi,
    this.onRandevu,
    this.onizleme = false,
  });

  final VitrinSalonu salon;

  /// Hizmetler, galeri, ekip ve yorumlar; yüklenirken null.
  final VitrinVerisi? veri;
  final String? hata;
  final VoidCallback? onTekrar;
  final String? kahramanEtiketi;
  final VoidCallback? onRandevu;

  /// true: kaydırma ve düğmeler kapalı (işletmenin gördüğü önizleme).
  final bool onizleme;

  @override
  State<MaisonVitrinGorunumu> createState() => _MaisonVitrinGorunumuState();
}

class _MaisonVitrinGorunumuState extends State<MaisonVitrinGorunumu> {
  int? _sekme;

  static List<String> get _sekmeler => <String>[
        dl('Hizmetler', 'Services'),
        dl('Galeri', 'Gallery'),
        dl('Ekip', 'Team'),
        dl('Yorumlar', 'Reviews'),
      ];

  int get _gecerliSekme {
    final int? secili = _sekme;
    if (secili != null) {
      return secili;
    }
    final VitrinVerisi? v = widget.veri;
    return v != null && v.galeri.isNotEmpty ? 1 : 0;
  }

  Future<void> _ac(Uri adres) async {
    if (widget.onizleme) {
      return;
    }
    final ScaffoldMessengerState? mesaj = ScaffoldMessenger.maybeOf(context);
    bool acildi = false;
    try {
      acildi = await launchUrl(adres, mode: LaunchMode.externalApplication);
    } catch (_) {
      acildi = false;
    }
    if (!acildi) {
      mesaj?.showSnackBar(SnackBar(content: Text(dl('Bu bağlantı açılamadı.', 'This link could not be opened.'))));
    }
  }

  void _galeriyiAc(List<VitrinFotografi> galeri, int ilk, VitrinFiltresi filtre) {
    if (widget.onizleme) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MaisonFotoGosterici(
          adresler: galeri.map((VitrinFotografi f) => f.url).toList(),
          aciklamalar: galeri.map((VitrinFotografi f) => f.aciklama).toList(),
          ilk: ilk,
          filtre: filtre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final VitrinSalonu s = widget.salon;
    final double ust = MediaQuery.paddingOf(context).top;
    final double alt = MediaQuery.paddingOf(context).bottom;
    final double kapakYuksekligi = 250 + ust;
    final int sekme = _gecerliSekme;
    return CustomScrollView(
      physics: widget.onizleme ? const NeverScrollableScrollPhysics() : null,
      slivers: <Widget>[
        SliverToBoxAdapter(child: _kapakVeLogo(r, s, kapakYuksekligi, ust)),
        SliverToBoxAdapter(child: _baslik(r, s)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SekmeSeridi(
            adlar: _sekmeler,
            secili: sekme,
            renkler: r,
            onSec: (int i) => setState(() => _sekme = i),
          ),
        ),
        ..._icerik(r, s, sekme),
        SliverToBoxAdapter(child: SizedBox(height: 32 + alt)),
      ],
    );
  }

  Widget _kapakVeLogo(MaisonRenkler r, VitrinSalonu s, double kapakYuksekligi, double ust) {
    final Widget kapak = MaisonKapak(
      yukseklik: kapakYuksekligi,
      url: s.kapakUrl,
      odak: s.kapakOdak,
      filtre: s.ayar.filtre,
    );
    final String? etiket = widget.kahramanEtiketi;
    final bool geriVar = !widget.onizleme && (Navigator.maybeOf(context)?.canPop() ?? false);
    final String? logo = s.logoUrl;
    return SizedBox(
      height: kapakYuksekligi + 44,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: kapakYuksekligi,
            child: etiket == null ? kapak : Hero(tag: etiket, child: kapak),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: kapakYuksekligi - 120,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[r.zemin.withValues(alpha: 0), r.zemin],
                  ),
                ),
              ),
            ),
          ),
          if (geriVar)
            Positioned(
              left: 16,
              top: ust + 8,
              child: MaisonYuvarlakDugme(
                ikon: Icons.arrow_back,
                etiket: dl('Geri', 'Back'),
                zemin: r.zemin.withValues(alpha: 0.6),
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          Positioned(
            left: 20,
            top: kapakYuksekligi - 44,
            child: Container(
              width: 76,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: r.kart,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: r.vurgu, width: 1.5),
              ),
              child: logo != null && logo.isNotEmpty
                  ? MaisonFoto(url: logo, zemin: r.kart, etiket: dl('${s.ad} logosu', '${s.ad} logo'))
                  : Center(
                      child: Text(
                        s.basHarfler,
                        style: maisonBaslik(30, renk: r.vurgu, kalinlik: FontWeight.w600, yukseklik: 1.0, aralik: 1.2),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _baslik(MaisonRenkler r, VitrinSalonu s) {
    final String? tel = s.telefon;
    final String? whatsapp = maisonUluslararasiTelefon(tel);
    final String telRakam = (tel ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    final String yolSorgusu = <String?>[s.ad, s.adres, s.ilce, s.sehir]
        .whereType<String>()
        .where((String p) => p.trim().isNotEmpty)
        .join(', ');
    final String? aciklama = s.aciklama;
    void hic() {}
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: <Widget>[
              Text(s.ad, style: maisonBaslik(36, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.05)),
              if (s.dogrulandi)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.verified_outlined, size: 16, color: r.vurgu),
                    const SizedBox(width: 4),
                    Text(dl('Doğrulanmış', 'Verified'), style: maisonGovde(12, renk: r.vurgu, kalinlik: FontWeight.w500)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.star, size: 14, color: r.vurgu),
                  ),
                ),
                TextSpan(
                  text: s.puanMetni,
                  style: maisonGovde(14, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                ),
                if (s.yorumAdet > 0) TextSpan(text: dl('  (${s.yorumAdet} yorum)', '  (${s.yorumAdet} review${s.yorumAdet == 1 ? '' : 's'})')),
                if (s.yer.isNotEmpty) TextSpan(text: '  ·  ${s.yer}'),
              ],
            ),
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.3),
          ),
          if (widget.veri?.saatler case final SalonSaatleri saatler when !saatler.bos)
            _durumSatiri(r, saatler),
          if (aciklama != null && aciklama.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              aciklama.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: widget.onizleme ? hic : widget.onRandevu,
              child: Text(dl('Randevu Al', 'Book')),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _EylemDugmesi(
                  ikon: Icons.call_outlined,
                  etiket: dl('Ara', 'Call'),
                  onTap: telRakam.length < 7
                      ? null
                      : () => _ac(Uri(scheme: 'tel', path: telRakam)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EylemDugmesi(
                  ikon: Icons.place_outlined,
                  etiket: dl('Yol tarifi', 'Directions'),
                  onTap: () => _ac(Uri.https('www.google.com', '/maps/search/', <String, String>{
                    'api': '1',
                    'query': yolSorgusu,
                  })),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EylemDugmesi(
                  ikon: Icons.chat_bubble_outline,
                  etiket: dl('Mesaj', 'Message'),
                  onTap: whatsapp == null ? null : () => _ac(Uri.https('wa.me', '/$whatsapp')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Şu an açık · 20:00'de kapanır" satırı; dokununca haftalık saatler açılır.
  Widget _durumSatiri(MaisonRenkler r, SalonSaatleri saatler) {
    final SalonDurumu? d = saatler.durum();
    final String metin = d?.metin ?? dl('Çalışma saatleri', 'Opening hours');
    final bool acik = d?.acik ?? false;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.onizleme
              ? null
              : () => maisonHaftalikSaatleriGoster(context, baslik: dl('Çalışma saatleri', 'Opening hours'), saatler: saatler),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: acik ? const Color(0xFF3FA66B) : r.soluk,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    metin,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: maisonGovde(14, renk: acik ? r.yazi : r.soluk, kalinlik: FontWeight.w500, yukseklik: 1.3),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 18, color: r.soluk),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _icerik(MaisonRenkler r, VitrinSalonu s, int sekme) {
    final String? hata = widget.hata;
    if (hata != null && widget.veri == null) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(child: MaisonHataKutusu(hata, tekrar: widget.onTekrar)),
        ),
      ];
    }
    final VitrinVerisi? v = widget.veri;
    if (v == null) {
      return const <Widget>[SliverToBoxAdapter(child: MaisonYukleniyor())];
    }
    switch (sekme) {
      case 1:
        return _galeri(r, s, v.galeri);
      case 2:
        return _ekip(r, v.ekip);
      case 3:
        return _yorumlar(r, s, v.yorumlar);
      default:
        return _hizmetler(r, s, v.hizmetler);
    }
  }

  List<Widget> _bos(IconData ikon, String baslik, String aciklama) {
    return <Widget>[
      SliverToBoxAdapter(
        child: MaisonBosDurum(ikon: ikon, baslik: baslik, aciklama: aciklama),
      ),
    ];
  }

  List<Widget> _hizmetler(MaisonRenkler r, VitrinSalonu s, List<VitrinHizmeti> hizmetler) {
    if (hizmetler.isEmpty) {
      return _bos(Icons.content_cut, dl('Hizmet menüsü yakında', 'Service menu coming soon'), dl('Salon hizmetlerini ve fiyatlarını eklediğinde burada görünecek.', 'It will appear here once the salon adds its services and prices.'));
    }
    // Kategori başlıkları yalnız birden çok kategori varsa gösterilir.
    final Set<HizmetKategorisi> kategoriler = hizmetler.map((VitrinHizmeti h) => h.kategori).toSet();
    final List<Object> satirlar = <Object>[
      for (final HizmetKategorisi k in HizmetKategorisi.values)
        if (kategoriler.contains(k)) ...<Object>[
          if (kategoriler.length > 1) k,
          ...hizmetler.where((VitrinHizmeti h) => h.kategori == k),
        ],
    ];
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        sliver: SliverList.builder(
          itemCount: satirlar.length,
          itemBuilder: (BuildContext context, int i) {
            final Object satir = satirlar[i];
            if (satir is HizmetKategorisi) {
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 12 : 26, bottom: 2),
                child: MaisonUstBaslik(maisonBuyukHarf(satir.ad)),
              );
            }
            final VitrinHizmeti h = satir as VitrinHizmeti;
            final String? aciklama = h.aciklama;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(h.ad, style: maisonGovde(16, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.3)),
                        if (aciklama != null && aciklama.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            aciklama.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(maisonSure(h.sureDk), style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    maisonPara(h.fiyat, s.paraBirimi),
                    style: maisonGovde(16, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _galeri(MaisonRenkler r, VitrinSalonu s, List<VitrinFotografi> galeri) {
    if (galeri.isEmpty) {
      return _bos(Icons.photo_library_outlined, dl('Galeri yakında', 'Gallery coming soon'), dl('Salon fotoğraf ekledikçe çalışmaları burada görünecek.', "The salon's work will appear here as photos are added."));
    }
    final List<Widget> sol = <Widget>[];
    final List<Widget> sag = <Widget>[];
    for (int i = 0; i < galeri.length; i++) {
      final int satir = i ~/ 2;
      final bool solda = i.isEven;
      final bool uzun = solda ? satir.isEven : satir.isOdd;
      final Widget kutu = _GaleriKutusu(
        foto: galeri[i],
        yukseklik: uzun ? 176 : 120,
        filtre: s.ayar.filtre,
        renkler: r,
        onTap: () => _galeriyiAc(galeri, i, s.ayar.filtre),
      );
      (solda ? sol : sag).add(Padding(padding: const EdgeInsets.only(bottom: 10), child: kutu));
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Column(children: sol)),
              const SizedBox(width: 10),
              Expanded(child: Column(children: sag)),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _ekip(MaisonRenkler r, List<VitrinUstasi> ekip) {
    if (ekip.isEmpty) {
      return _bos(Icons.groups_outlined, dl('Ekip yakında', 'Team coming soon'), dl('Salon ustalarını eklediğinde burada görünecek.', 'It will appear here once the salon adds its barbers.'));
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: SliverList.builder(
          itemCount: ekip.length,
          itemBuilder: (BuildContext context, int i) {
            final VitrinUstasi u = ekip[i];
            final String? unvan = u.unvan;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
              child: Row(
                children: <Widget>[
                  MaisonAvatar(basHarfler: u.basHarfler, boyut: 56, fotoUrl: u.fotoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(u.ad, style: maisonGovde(16, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3)),
                        if (unvan != null && unvan.trim().isNotEmpty)
                          Text(unvan, style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3)),
                        if (u.uzmanlik.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: <Widget>[
                              for (final String uzmanlik in u.uzmanlik.take(4))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: r.vurguYumusak,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    uzmanlik,
                                    style: maisonGovde(11, renk: r.vurgu, kalinlik: FontWeight.w600, yukseklik: 1.2),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _yorumlar(MaisonRenkler r, VitrinSalonu s, List<VitrinYorumu> yorumlar) {
    if (yorumlar.isEmpty) {
      return _bos(
        Icons.rate_review_outlined,
        dl('Henüz yorum yok', 'No reviews yet'),
        dl('Yorumları yalnız bu salondan randevu alıp hizmeti tamamlayan müşteriler yazabilir.', 'Only customers who booked and completed a service at this salon can write reviews.'),
      );
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(s.puanMetni, style: maisonBaslik(44, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.0)),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  dl('${s.yorumAdet} doğrulanmış yorum', '${s.yorumAdet} verified review${s.yorumAdet == 1 ? '' : 's'}'),
                  style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        sliver: SliverList.builder(
          itemCount: yorumlar.length,
          itemBuilder: (BuildContext context, int i) {
            final VitrinYorumu y = yorumlar[i];
            final String? metin = y.metin;
            final String? yanit = y.yanit;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          y.gorunenAd,
                          style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                        ),
                      ),
                      Text(maisonTarih(y.olusturuldu), style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      for (int k = 1; k <= 5; k++)
                        Icon(k <= y.puan ? Icons.star : Icons.star_border, size: 14, color: r.vurgu),
                    ],
                  ),
                  if (metin != null && metin.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(metin.trim(), style: maisonGovde(14, renk: r.yazi, yukseklik: 1.5)),
                  ],
                  if (yanit != null && yanit.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: r.kart,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        dl('Salonun yanıtı: ${yanit.trim()}', "Salon's reply: ${yanit.trim()}"),
                        style: maisonGovde(13, renk: r.soluk, yukseklik: 1.5),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _EylemDugmesi extends StatelessWidget {
  const _EylemDugmesi({required this.ikon, required this.etiket, required this.onTap});

  final IconData ikon;
  final String etiket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(ikon, size: 16),
        label: Text(etiket, maxLines: 1, softWrap: false, overflow: TextOverflow.fade),
        style: OutlinedButton.styleFrom(
          foregroundColor: r.yazi,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: const StadiumBorder(),
          side: BorderSide(color: r.cizgi),
          textStyle: maisonGovde(14, kalinlik: FontWeight.w500),
        ),
      ),
    );
  }
}

class _GaleriKutusu extends StatelessWidget {
  const _GaleriKutusu({
    required this.foto,
    required this.yukseklik,
    required this.filtre,
    required this.renkler,
    required this.onTap,
  });

  final VitrinFotografi foto;
  final double yukseklik;
  final VitrinFiltresi filtre;
  final MaisonRenkler renkler;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? aciklama = foto.aciklama;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: yukseklik,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MaisonFoto(url: foto.url, filtre: filtre, zemin: renkler.kart, etiket: aciklama),
              if (aciklama != null && aciklama.trim().isNotEmpty)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xC70E0E10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        aciklama.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: maisonGovde(12, renk: const Color(0xFFF4F1EA), kalinlik: FontWeight.w500, yukseklik: 1.2),
                      ),
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

class _SekmeSeridi extends SliverPersistentHeaderDelegate {
  _SekmeSeridi({
    required this.adlar,
    required this.secili,
    required this.renkler,
    required this.onSec,
  });

  final List<String> adlar;
  final int secili;
  final MaisonRenkler renkler;
  final ValueChanged<int> onSec;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double kayma, bool ustuneBiniyor) {
    final MaisonRenkler r = renkler;
    return ColoredBox(
      color: r.zemin,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < adlar.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == secili,
                    child: InkWell(
                      onTap: () => onSec(i),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: i == secili ? r.vurgu : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          adlar[i],
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: maisonGovde(
                            14,
                            renk: i == secili ? r.yazi : r.soluk,
                            kalinlik: i == secili ? FontWeight.w600 : FontWeight.w500,
                            yukseklik: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SekmeSeridi eski) {
    return eski.secili != secili || eski.renkler != renkler || eski.adlar != adlar;
  }
}
