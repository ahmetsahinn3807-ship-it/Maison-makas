import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../veri.dart';

/// Randevularım: yaklaşan ve geçmiş randevular, yaklaşanlarda iptal.
class RandevularimEkrani extends StatefulWidget {
  const RandevularimEkrani({super.key, required this.menuAc, this.sekme = 0});

  final VoidCallback menuAc;

  /// 0 = yaklaşan, 1 = geçmiş. Menüden gelince değişir.
  final int sekme;

  @override
  State<RandevularimEkrani> createState() => _RandevularimEkraniState();
}

class _RandevularimEkraniState extends State<RandevularimEkrani> {
  late int _sekme = widget.sekme;
  Future<List<RandevuOzet>>? _gelecek;

  @override
  void initState() {
    super.initState();
    Veri.randevuSurumu.addListener(_randevuDegisti);
  }

  @override
  void dispose() {
    Veri.randevuSurumu.removeListener(_randevuDegisti);
    super.dispose();
  }

  /// Randevu alınınca ya da iptal edilince liste yenilenir.
  void _randevuDegisti() {
    if (mounted) {
      _yenile();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gelecek ??= _yukle();
  }

  @override
  void didUpdateWidget(RandevularimEkrani eski) {
    super.didUpdateWidget(eski);
    if (eski.sekme != widget.sekme && widget.sekme != _sekme) {
      _sekme = widget.sekme;
      _gelecek = _yukle();
    }
  }

  Future<List<RandevuOzet>> _yukle() => Veri.of(context).randevularim(gecmis: _sekme == 1);

  Future<void> _yenile() async {
    final Future<List<RandevuOzet>> f = _yukle();
    setState(() => _gelecek = f);
    try {
      await f;
    } catch (_) {
      // Hata listede gösterilir.
    }
  }

  void _sekmeSec(int sekme) {
    if (sekme == _sekme) {
      return;
    }
    setState(() {
      _sekme = sekme;
      _gelecek = _yukle();
    });
  }

  Future<void> _iptalEt(RandevuOzet randevu) async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: r.kart,
          title: Text(dl('Randevu iptal edilsin mi?', 'Cancel this booking?'), style: maisonBaslik(26, renk: r.yazi)),
          content: Text(
            dl('${randevu.salonAd} · ${maisonGun(randevu.baslangic)} ${maisonSaat(randevu.baslangic)}\n'
            'Ücretsiz iptal süresi geçtiyse salon bunu kaydeder.', '${randevu.salonAd} · ${maisonGun(randevu.baslangic)} ${maisonSaat(randevu.baslangic)}\n'
                'If the free cancellation window has passed, the salon will note it.'),
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dl('Vazgeç', 'Keep it')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(dl('İptal et', 'Cancel booking'), style: maisonGovde(14, renk: Theme.of(context).colorScheme.error, kalinlik: FontWeight.w600)),
            ),
          ],
        );
      },
    );
    if (onay != true || !mounted) {
      return;
    }
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    final Veri veri = Veri.of(context);
    try {
      await veri.randevuIptal(randevu.id);
      mesaj.showSnackBar(SnackBar(content: Text(dl('Randevun iptal edildi.', 'Your booking has been cancelled.'))));
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return RefreshIndicator(
      color: r.vurgu,
      backgroundColor: r.kart,
      onRefresh: _yenile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          MaisonUstSatir(
            sol: MaisonYuvarlakDugme(ikon: Icons.menu, etiket: dl('Menüyü aç', 'Open menu'), onTap: widget.menuAc),
            baslik: dl('Randevularım', 'My bookings'),
          ),
          const SizedBox(height: 18),
          MaisonSekmeSecici(
            secenekler: <String>[dl('Yaklaşan', 'Upcoming'), dl('Geçmiş', 'Past')],
            secili: _sekme,
            onSec: _sekmeSec,
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<RandevuOzet>>(
            future: _gelecek,
            builder: (BuildContext context, AsyncSnapshot<List<RandevuOzet>> durum) {
              if (durum.hasError) {
                return MaisonHataKutusu(maisonHataMetni(durum.error!), tekrar: _yenile);
              }
              final List<RandevuOzet>? liste = durum.data;
              if (liste == null) {
                return const MaisonYukleniyor();
              }
              if (liste.isEmpty) {
                return MaisonBosDurum(
                  ikon: _sekme == 0 ? Icons.event_available_outlined : Icons.history,
                  baslik: _sekme == 0 ? dl('Yaklaşan randevun yok', 'No upcoming bookings') : dl('Geçmiş randevun yok', 'No past bookings'),
                  aciklama: _sekme == 0
                      ? dl('Aldığın randevular burada, saat sırasıyla görünür.', 'Your bookings appear here in time order.')
                      : dl('Tamamlanan ve iptal edilen randevular burada durur.', 'Completed and cancelled bookings are kept here.'),
                );
              }
              return Column(
                children: <Widget>[
                  for (final RandevuOzet rv in liste)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RandevuKarti(
                        randevu: rv,
                        onIptal: _sekme == 0 ? () => _iptalEt(rv) : null,
                      ),
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

class _RandevuKarti extends StatelessWidget {
  const _RandevuKarti({required this.randevu, this.onIptal});

  final RandevuOzet randevu;
  final VoidCallback? onIptal;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final RandevuOzet rv = randevu;
    final bool sonuk = rv.durum == 'iptal' || rv.durum == 'gelmedi';
    final double? fiyat = rv.toplamFiyat;
    final VoidCallback? iptal = onIptal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: r.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 54,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: r.cizgi),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      maisonAyBuyuk(rv.baslangic),
                      style: maisonGovde(10, renk: r.soluk, yukseklik: 1.2, aralik: 1.2),
                    ),
                    Text(
                      '${rv.baslangic.day}',
                      style: maisonBaslik(27, renk: sonuk ? r.soluk : r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.0),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${maisonGun(rv.baslangic)} · ${maisonSaat(rv.baslangic)}–${maisonSaat(rv.bitis)}',
                      style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rv.salonIlce == null ? rv.salonAd : '${rv.salonAd}, ${rv.salonIlce}',
                      style: maisonGovde(14, renk: r.soluk, yukseklik: 1.35),
                    ),
                    Text(
                      '${rv.hizmetler ?? dl('Randevu', 'Booking')} · ${rv.ustaAd}',
                      style: maisonGovde(14, renk: r.soluk, yukseklik: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sonuk ? r.girdi : r.vurguYumusak,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  rv.durumMetni,
                  style: maisonGovde(12, renk: sonuk ? r.soluk : r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.2),
                ),
              ),
              const Spacer(),
              if (fiyat != null)
                Text(
                  maisonPara(fiyat, rv.paraBirimi),
                  style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.2),
                ),
            ],
          ),
          if (iptal != null) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: OutlinedButton(onPressed: iptal, child: Text(dl('Randevuyu iptal et', 'Cancel booking'))),
            ),
          ],
        ],
      ),
    );
  }
}
