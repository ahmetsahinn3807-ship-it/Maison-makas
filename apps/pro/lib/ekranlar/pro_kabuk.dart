import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../canli_takip.dart';
import '../salon.dart';
import 'ekip_ekrani.dart';
import 'hazirlik_karti.dart';
import 'hizmetler_ekrani.dart';
import 'pro_ayarlar.dart';
import 'randevu_islemleri.dart';
import 'randevular_ekrani.dart';
import 'salon_bilgileri_ekrani.dart';
import 'takvim_ekrani.dart';
import 'vitrin_studyosu.dart';

/// Makas Pro ana iskeleti: soldan menü ve Bugün ekranı.
class ProKabuk extends StatefulWidget {
  const ProKabuk({super.key, required this.salon, required this.yenile});

  final ProSalon salon;

  /// Salon bilgisi değişince (ör. yayına alınınca) yeniden yükler.
  final VoidCallback yenile;

  @override
  State<ProKabuk> createState() => _ProKabukState();
}

class _ProKabukState extends State<ProKabuk> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _iskele = GlobalKey<ScaffoldState>();
  SalonDinleyici? _dinleyici;
  bool _onde = true;
  int _bildirimNo = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _canliTakibiBaslat());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dinleyici?.durdur();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    _onde = durum == AppLifecycleState.resumed;
  }

  /// Yeni randevu ve iptaller: uygulama öndeyse ekranda, arkadaysa bildirim olarak.
  void _canliTakibiBaslat() {
    if (!mounted) {
      return;
    }
    final SupabaseClient? istemci = OturumKapsami.oku(context).istemci;
    if (istemci == null) {
      return;
    }
    MaisonBildirim.izinIste();
    _dinleyici = SalonDinleyici(
      istemci: istemci,
      salonId: widget.salon.id,
      onDegisti: () {
        if (mounted) {
          setState(() => _surum++);
        }
      },
      onBildir: (String baslik, String metin) {
        if (!mounted) {
          return;
        }
        if (_onde) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$baslik · $metin')));
        } else if (!MaisonPush.etkin) {
          // Uzaktan bildirim kuruluysa telefon onu zaten gösterir; ikinci kez gösterilmez.
          MaisonBildirim.goster(id: 3000 + (_bildirimNo++ % 50), baslik: baslik, metin: metin);
        }
      },
    )..baslat();
  }

  /// Bir ekrandan dönülünce artar; Bugün'deki hazırlık listesi yeniden okunur.
  int _surum = 0;

  Future<void> _ac(Widget sayfa) async {
    _iskele.currentState?.closeDrawer();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (BuildContext context) => sayfa));
    if (mounted) {
      setState(() => _surum++);
    }
  }

  void _hizmetleriAc() => _ac(HizmetlerEkrani(salon: widget.salon));

  void _ekibiAc() => _ac(EkipEkrani(salon: widget.salon, salonDegisti: widget.yenile));

  void _vitriniAc() => _ac(VitrinStudyosu(salon: widget.salon, salonDegisti: widget.yenile));

  void _bilgileriAc() => _ac(SalonBilgileriEkrani(salon: widget.salon, salonDegisti: widget.yenile));

  void _ayarlariAc() => _ac(ProAyarlar(salon: widget.salon, salonDegisti: widget.yenile));

  void _yakinda(String baslik, IconData ikon, String aciklama) {
    _ac(MaisonYakindaEkrani(baslik: baslik, ikon: ikon, aciklama: aciklama));
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonTercih.proPaleti),
      child: Scaffold(
        key: _iskele,
        backgroundColor: r.zemin,
        drawer: _ProMenu(
          salon: widget.salon,
          bugun: () => _iskele.currentState?.closeDrawer(),
          takvim: () => _ac(TakvimEkrani(salon: widget.salon)),
          randevular: () => _ac(RandevularEkrani(salon: widget.salon)),
          musteriler: () => _yakinda(dl('Müşteriler', 'Customers'), Icons.people_outline,
              dl('Müşteri kartları, notlar ve stil geçmişi sıradaki adımlarda geliyor.', 'Customer cards, notes and style history are coming in a future update.')),
          ekip: _ekibiAc,
          hizmetler: _hizmetleriAc,
          vitrin: _vitriniAc,
          kasa: () => _yakinda(dl('Kasa ve adisyon', 'Till and receipts'), Icons.point_of_sale_outlined,
              dl('Biten randevular adisyona dönüşecek; günlük ve aylık ciro burada.', 'Finished bookings will become receipts; daily and monthly takings will be here.')),
          raporlar: () => _yakinda(dl('Raporlar', 'Reports'), Icons.insights_outlined,
              dl('Doluluk, gelir ve müşteri raporları premium pakette geliyor.', 'Occupancy, revenue and customer reports are coming in the premium plan.')),
          ayarlar: _ayarlariAc,
        ),
        body: SafeArea(
          child: _BugunEkrani(
            salon: widget.salon,
            menuAc: () => _iskele.currentState?.openDrawer(),
            surum: _surum,
            hazirlik: widget.salon.sahibim
                ? HazirlikKarti(
                    salon: widget.salon,
                    surum: _surum,
                    hizmetler: _hizmetleriAc,
                    ekip: _ekibiAc,
                    vitrin: _vitriniAc,
                    bilgiler: _bilgileriAc,
                    ayarlar: _ayarlariAc,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _ProMenu extends StatelessWidget {
  const _ProMenu({
    required this.salon,
    required this.bugun,
    required this.takvim,
    required this.randevular,
    required this.musteriler,
    required this.ekip,
    required this.hizmetler,
    required this.vitrin,
    required this.kasa,
    required this.raporlar,
    required this.ayarlar,
  });

  final ProSalon salon;
  final VoidCallback bugun;
  final VoidCallback takvim;
  final VoidCallback randevular;
  final VoidCallback musteriler;
  final VoidCallback ekip;
  final VoidCallback hizmetler;
  final VoidCallback vitrin;
  final VoidCallback kasa;
  final VoidCallback raporlar;
  final VoidCallback ayarlar;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final MaisonOturum oturum = OturumKapsami.of(context);
    final double ust = MediaQuery.paddingOf(context).top;
    final double kapak = 96 + ust;
    final String yer = <String?>[salon.ilce, salon.sehir]
        .whereType<String>()
        .where((String s) => s.trim().isNotEmpty)
        .join(', ');
    return Drawer(
      width: 306,
      backgroundColor: r.menu,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        side: BorderSide(color: r.cizgi),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                SizedBox(
                  height: kapak + 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(left: 0, right: 0, top: 0, child: MaisonKapak(yukseklik: kapak)),
                      Positioned(
                        right: 12,
                        top: ust + 8,
                        child: MaisonYuvarlakDugme(
                          ikon: Icons.close,
                          etiket: dl('Menüyü kapat', 'Close menu'),
                          zemin: r.zemin.withValues(alpha: 0.6),
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        top: kapak - 34,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Container(
                              width: 72,
                              height: 72,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: r.menu,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: r.kart,
                                  borderRadius: BorderRadius.circular(19),
                                  border: Border.all(color: r.vurgu, width: 1.5),
                                ),
                                child: MaisonAmblem(renk: r.vurgu, zemin: r.kart, genislik: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    salon.ad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: maisonGovde(17, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.25),
                                  ),
                                  Text(
                                    yer.isEmpty ? (salon.sahibim ? dl('Salon sahibi', 'Salon owner') : dl('Usta', 'Barber')) : yer,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: maisonGovde(13, renk: r.soluk, yukseklik: 1.3),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: salon.yayinda ? r.vurguYumusak : r.girdi,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: salon.yayinda ? r.vurguCizgi : r.cizgi),
                        ),
                        child: Text(
                          salon.yayinda ? dl('Yayında', 'Live') : dl('Taslak', 'Draft'),
                          style: maisonGovde(12, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          oturum.adSoyad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Divider(color: r.cizgi, height: 1, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: <Widget>[
                      _Satir(ikon: Icons.today_outlined, etiket: dl('Bugün', 'Today'), vurgulu: true, onTap: bugun),
                      _Satir(ikon: Icons.calendar_month_outlined, etiket: dl('Takvim', 'Calendar'), onTap: takvim),
                      _Satir(ikon: Icons.event_note_outlined, etiket: dl('Randevular', 'Bookings'), onTap: randevular),
                      _Satir(ikon: Icons.people_outline, etiket: dl('Müşteriler', 'Customers'), onTap: musteriler),
                      _Satir(ikon: Icons.groups_outlined, etiket: dl('Ekip', 'Team'), onTap: ekip),
                      _Satir(ikon: Icons.content_cut, etiket: dl('Hizmetler', 'Services'), onTap: hizmetler),
                      _Satir(ikon: Icons.storefront_outlined, etiket: dl('Vitrin Stüdyosu', 'Showcase Studio'), onTap: vitrin),
                      _Satir(ikon: Icons.point_of_sale_outlined, etiket: dl('Kasa ve adisyon', 'Till and receipts'), onTap: kasa),
                      _Satir(ikon: Icons.insights_outlined, etiket: dl('Raporlar', 'Reports'), onTap: raporlar),
                      _Satir(ikon: Icons.tune, etiket: dl('Ayarlar', 'Settings'), onTap: ayarlar),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({
    required this.ikon,
    required this.etiket,
    required this.onTap,
    this.vurgulu = false,
  });

  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;
  final bool vurgulu;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: vurgulu ? r.vurguYumusak : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(ikon, size: 20, color: vurgulu ? r.vurgu : r.soluk),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                etiket,
                style: maisonGovde(
                  15,
                  renk: r.yazi,
                  kalinlik: vurgulu ? FontWeight.w600 : FontWeight.w400,
                  yukseklik: 1.2,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: r.soluk.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

/// Bugün: günün randevuları, sayı ve tahmini ciro.
class _BugunEkrani extends StatefulWidget {
  const _BugunEkrani({required this.salon, required this.menuAc, required this.surum, this.hazirlik});

  final ProSalon salon;
  final VoidCallback menuAc;

  /// Başka bir ekrandan dönülünce artar; günün listesi yeniden okunur.
  final int surum;

  /// Salon sahibine "Salonun randevuya hazır mı?" listesi.
  final Widget? hazirlik;

  @override
  State<_BugunEkrani> createState() => _BugunEkraniState();
}

class _BugunEkraniState extends State<_BugunEkrani> {
  Future<List<TakvimKaydi>>? _gelecek;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gelecek ??= _yukle();
  }

  @override
  void didUpdateWidget(_BugunEkrani eski) {
    super.didUpdateWidget(eski);
    if (eski.surum != widget.surum) {
      _yenile();
    }
  }

  Future<void> _ayrinti(TakvimKaydi k) async {
    if (await randevuAyrintisiAc(context, k) && mounted) {
      await _yenile();
    }
  }

  Future<void> _kapidanGelen() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    TakvimTanimlari tanim;
    try {
      tanim = await TakvimTanimlari.yukle(await oturum.istemciGerekli(), widget.salon, oturum.kullanici?.id);
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
      return;
    }
    if (!mounted) {
      return;
    }
    if (await kapidanGelenAc(context, salon: widget.salon, tanimlar: tanim) && mounted) {
      await _yenile();
    }
  }

  Future<List<TakvimKaydi>> _yukle() async {
    final SupabaseClient? i = OturumKapsami.oku(context).istemci;
    if (i == null) {
      return <TakvimKaydi>[];
    }
    final DateTime simdi = DateTime.now();
    final DateTime bas = DateTime(simdi.year, simdi.month, simdi.day);
    final DateTime son = bas.add(const Duration(days: 1));
    final Object? sonuc = await i.rpc('salon_takvimi', params: <String, dynamic>{
      'p_salon': widget.salon.id,
      'p_bas': bas.toUtc().toIso8601String(),
      'p_son': son.toUtc().toIso8601String(),
    });
    if (sonuc is! List) {
      return <TakvimKaydi>[];
    }
    return sonuc.whereType<Map<String, dynamic>>().map(TakvimKaydi.json).toList();
  }

  Future<void> _yenile() async {
    final Future<List<TakvimKaydi>> f = _yukle();
    setState(() => _gelecek = f);
    try {
      await f;
    } catch (_) {
      // Hata listede gösterilir.
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final DateTime bugun = DateTime.now();
    return RefreshIndicator(
      color: r.vurgu,
      backgroundColor: r.kart,
      onRefresh: _yenile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          MaisonUstSatir(
            sol: MaisonYuvarlakDugme(ikon: Icons.menu, etiket: dl('Menüyü aç', 'Open menu'), onTap: widget.menuAc),
            baslik: widget.salon.ad,
          ),
          const SizedBox(height: 20),
          MaisonUstBaslik('${maisonGunBuyuk(bugun)} · ${bugun.day} ${maisonAyBuyuk(bugun)}'),
          const SizedBox(height: 4),
          Text(dl('Bugün', 'Today'), style: maisonBaslik(42, renk: r.yazi, yukseklik: 1.05)),
          const SizedBox(height: 18),
          if (widget.hazirlik case final Widget hazirlik) hazirlik,
          FutureBuilder<List<TakvimKaydi>>(
            future: _gelecek,
            builder: (BuildContext context, AsyncSnapshot<List<TakvimKaydi>> durum) {
              if (durum.hasError) {
                return MaisonHataKutusu(maisonHataMetni(durum.error!), tekrar: _yenile);
              }
              final List<TakvimKaydi>? liste = durum.data;
              if (liste == null) {
                return const MaisonYukleniyor();
              }
              final List<TakvimKaydi> randevular =
                  liste.where((TakvimKaydi k) => k.tur == 'randevu' && k.etkin).toList();
              double ciro = 0;
              for (final TakvimKaydi k in randevular) {
                ciro += k.toplamFiyat ?? 0;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: _Ozet(baslik: dl('RANDEVU', 'BOOKINGS'), deger: '${randevular.length}')),
                      const SizedBox(width: 12),
                      Expanded(child: _Ozet(baslik: dl('TAHMİNİ CİRO', 'ESTIMATED TAKINGS'), deger: maisonPara(ciro, 'TRY'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _kapidanGelen,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      label: Text(dl('Kapıdan gelen müşteri', 'Walk-in customer')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (liste.isEmpty)
                    MaisonBosDurum(
                      ikon: Icons.event_available_outlined,
                      baslik: dl('Bugün randevu yok', 'No bookings today'),
                      aciklama: widget.salon.yayinda
                          ? dl('Müşteriler randevu aldıkça burada saat sırasıyla görünecek.', 'Bookings will appear here in time order as customers book.')
                          : dl('Hizmetlerini ve çalışma saatlerini ekleyip salonu yayına aldığında randevular burada görünecek.', 'Once you add your services and working hours and publish the salon, bookings will appear here.'),
                    )
                  else
                    for (final TakvimKaydi k in liste)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TakvimSatiri(kayit: k, onTap: () => _ayrinti(k)),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Ozet extends StatelessWidget {
  const _Ozet({required this.baslik, required this.deger});

  final String baslik;
  final String deger;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: r.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MaisonUstBaslik(baslik),
          const SizedBox(height: 6),
          Text(
            deger,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.0),
          ),
        ],
      ),
    );
  }
}
