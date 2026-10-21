import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../veri.dart';
import 'salon_ekrani.dart';

/// Keşfet: yayındaki salonlar ve arama.
class KesfetEkrani extends StatefulWidget {
  const KesfetEkrani({super.key, required this.menuAc});

  final VoidCallback menuAc;

  @override
  State<KesfetEkrani> createState() => _KesfetEkraniState();
}

class _KesfetEkraniState extends State<KesfetEkrani> {
  final TextEditingController _arama = TextEditingController();
  Future<List<SalonOzet>>? _gelecek;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gelecek ??= _yukle();
  }

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<List<SalonOzet>> _yukle() {
    final String metin = _arama.text.trim();
    return Veri.of(context).kesfet(arama: metin.isEmpty ? null : metin);
  }

  Future<void> _yenile() async {
    final Future<List<SalonOzet>> f = _yukle();
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
    return RefreshIndicator(
      color: r.vurgu,
      backgroundColor: r.kart,
      onRefresh: _yenile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: <Widget>[
          MaisonUstSatir(
            sol: MaisonYuvarlakDugme(ikon: Icons.menu, etiket: 'Menüyü aç', onTap: widget.menuAc),
            baslik: 'Keşfet',
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _arama,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _yenile(),
            style: maisonGovde(15, renk: r.yazi, yukseklik: 1.3),
            cursorColor: r.vurgu,
            decoration: InputDecoration(
              hintText: 'Salon, semt ya da şehir ara',
              hintStyle: maisonGovde(15, renk: r.soluk, yukseklik: 1.3),
              prefixIcon: Icon(Icons.search, color: r.soluk, size: 20),
              suffixIcon: IconButton(
                tooltip: 'Ara',
                onPressed: _yenile,
                icon: Icon(Icons.arrow_forward, color: r.vurgu, size: 20),
              ),
              filled: true,
              fillColor: r.girdi,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide(color: r.cizgi),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide(color: r.cizgi),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide(color: r.vurgu, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<SalonOzet>>(
            future: _gelecek,
            builder: (BuildContext context, AsyncSnapshot<List<SalonOzet>> durum) {
              if (durum.hasError) {
                return MaisonHataKutusu(maisonHataMetni(durum.error!), tekrar: _yenile);
              }
              final List<SalonOzet>? salonlar = durum.data;
              if (salonlar == null) {
                return const MaisonYukleniyor();
              }
              if (salonlar.isEmpty) {
                return MaisonBosDurum(
                  ikon: Icons.storefront_outlined,
                  baslik: _arama.text.trim().isEmpty ? 'Henüz salon yok' : 'Sonuç bulunamadı',
                  aciklama: _arama.text.trim().isEmpty
                      ? 'Salonlar Makas Pro\'dan katıldıkça burada görünecek.'
                      : 'Başka bir salon adı, semt ya da şehir dene.',
                );
              }
              return Column(
                children: <Widget>[
                  for (final SalonOzet s in salonlar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _SalonSatiri(salon: s),
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

class _SalonSatiri extends StatelessWidget {
  const _SalonSatiri({required this.salon});

  final SalonOzet salon;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String etiket = 'kesfet-salon-${salon.id}';
    return Material(
      color: r.kart,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => SalonEkrani(salon: salon, kahramanEtiketi: etiket),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Hero(
              tag: etiket,
              child: MaisonKapak(
                yukseklik: 140,
                url: salon.kapakUrl,
                odak: salon.kapakOdak,
                filtre: salon.ayar.filtre,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          salon.ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Icon(Icons.star, size: 14, color: r.vurgu),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                salon.ozet,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: maisonGovde(13, renk: r.soluk, yukseklik: 1.2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (salon.dogrulandi) Icon(Icons.verified_outlined, color: r.vurgu, size: 20),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: r.soluk),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
