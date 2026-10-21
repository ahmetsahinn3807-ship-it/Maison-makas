import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../salon.dart';
import 'pro_ayarlar.dart';
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

class _ProKabukState extends State<ProKabuk> {
  final GlobalKey<ScaffoldState> _iskele = GlobalKey<ScaffoldState>();

  void _ac(Widget sayfa) {
    _iskele.currentState?.closeDrawer();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (BuildContext context) => sayfa));
  }

  void _yakinda(String baslik, IconData ikon, String aciklama) {
    _ac(MaisonYakindaEkrani(baslik: baslik, ikon: ikon, aciklama: aciklama));
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonPalet.ivoire),
      child: Scaffold(
        key: _iskele,
        backgroundColor: r.zemin,
        drawer: _ProMenu(
          salon: widget.salon,
          bugun: () => _iskele.currentState?.closeDrawer(),
          takvim: () => _yakinda('Takvim', Icons.calendar_month_outlined,
              'Haftalık takvim, sürükle-bırak ve kapıdan gelen müşteri 21. adımda geliyor.'),
          randevular: () => _yakinda('Randevular', Icons.event_note_outlined,
              'Tüm randevuların listesi ve arama 21. adımda geliyor.'),
          musteriler: () => _yakinda('Müşteriler', Icons.people_outline,
              'Müşteri kartları, notlar ve stil geçmişi sıradaki adımlarda geliyor.'),
          ekip: () => _yakinda('Ekip', Icons.groups_outlined,
              'Ustalar ve çalışma saatleri 20. adımda geliyor.'),
          hizmetler: () => _yakinda('Hizmetler', Icons.content_cut,
              'Hizmet menüsü, süreler ve fiyatlar 20. adımda geliyor.'),
          vitrin: () => _ac(VitrinStudyosu(salon: widget.salon, salonDegisti: widget.yenile)),
          kasa: () => _yakinda('Kasa ve adisyon', Icons.point_of_sale_outlined,
              'Biten randevular adisyona dönüşecek; günlük ve aylık ciro burada.'),
          raporlar: () => _yakinda('Raporlar', Icons.insights_outlined,
              'Doluluk, gelir ve müşteri raporları premium pakette geliyor.'),
          ayarlar: () => _ac(ProAyarlar(salon: widget.salon, salonDegisti: widget.yenile)),
        ),
        body: SafeArea(
          child: _BugunEkrani(
            salon: widget.salon,
            menuAc: () => _iskele.currentState?.openDrawer(),
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
                          etiket: 'Menüyü kapat',
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
                                    yer.isEmpty ? (salon.sahibim ? 'Salon sahibi' : 'Usta') : yer,
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
                          salon.yayinda ? 'Yayında' : 'Taslak',
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
                      _Satir(ikon: Icons.today_outlined, etiket: 'Bugün', vurgulu: true, onTap: bugun),
                      _Satir(ikon: Icons.calendar_month_outlined, etiket: 'Takvim', onTap: takvim),
                      _Satir(ikon: Icons.event_note_outlined, etiket: 'Randevular', onTap: randevular),
                      _Satir(ikon: Icons.people_outline, etiket: 'Müşteriler', onTap: musteriler),
                      _Satir(ikon: Icons.groups_outlined, etiket: 'Ekip', onTap: ekip),
                      _Satir(ikon: Icons.content_cut, etiket: 'Hizmetler', onTap: hizmetler),
                      _Satir(ikon: Icons.storefront_outlined, etiket: 'Vitrin Stüdyosu', onTap: vitrin),
                      _Satir(ikon: Icons.point_of_sale_outlined, etiket: 'Kasa ve adisyon', onTap: kasa),
                      _Satir(ikon: Icons.insights_outlined, etiket: 'Raporlar', onTap: raporlar),
                      _Satir(ikon: Icons.tune, etiket: 'Ayarlar', onTap: ayarlar),
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
  const _BugunEkrani({required this.salon, required this.menuAc});

  final ProSalon salon;
  final VoidCallback menuAc;

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
            sol: MaisonYuvarlakDugme(ikon: Icons.menu, etiket: 'Menüyü aç', onTap: widget.menuAc),
            baslik: widget.salon.ad,
          ),
          const SizedBox(height: 20),
          MaisonUstBaslik('${maisonGunBuyuk(bugun)} · ${bugun.day} ${maisonAyBuyuk(bugun)}'),
          const SizedBox(height: 4),
          Text('Bugün', style: maisonBaslik(42, renk: r.yazi, yukseklik: 1.05)),
          const SizedBox(height: 18),
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
                      Expanded(child: _Ozet(baslik: 'RANDEVU', deger: '${randevular.length}')),
                      const SizedBox(width: 12),
                      Expanded(child: _Ozet(baslik: 'TAHMİNİ CİRO', deger: maisonPara(ciro, 'TRY'))),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (liste.isEmpty)
                    MaisonBosDurum(
                      ikon: Icons.event_available_outlined,
                      baslik: 'Bugün randevu yok',
                      aciklama: widget.salon.yayinda
                          ? 'Müşteriler randevu aldıkça burada saat sırasıyla görünecek.'
                          : 'Hizmetlerini ve çalışma saatlerini ekleyip salonu yayına aldığında randevular burada görünecek.',
                    )
                  else
                    for (final TakvimKaydi k in liste)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _KayitSatiri(kayit: k),
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

class _KayitSatiri extends StatelessWidget {
  const _KayitSatiri({required this.kayit});

  final TakvimKaydi kayit;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final TakvimKaydi k = kayit;
    final bool blok = k.tur == 'blok';
    final bool sonuk = !k.etkin;
    final String baslik = blok ? 'Mola / blok' : (k.musteriAd ?? 'Misafir');
    final String alt = blok ? k.ustaAd : '${k.hizmetler ?? 'Randevu'} · ${k.ustaAd}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: blok ? r.girdi : r.kart,
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
                Text(
                  maisonSaat(k.baslangic),
                  style: maisonGovde(15, renk: sonuk ? r.soluk : r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
                ),
                Text(
                  maisonSaat(k.bitis),
                  style: maisonGovde(12, renk: r.soluk, yukseklik: 1.3),
                ),
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
          if (k.durum == 'iptal')
            Text('İptal', style: maisonGovde(12, renk: r.soluk, kalinlik: FontWeight.w600)),
        ],
      ),
    );
  }
}
