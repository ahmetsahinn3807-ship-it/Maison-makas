import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../salon.dart';
import 'randevu_islemleri.dart';
import 'takvim_ekrani.dart';

/// Randevular: yaklaşan (60 gün) ve geçmiş (60 gün) liste, müşteri adı ya da telefonla arama.
class RandevularEkrani extends StatefulWidget {
  const RandevularEkrani({super.key, required this.salon});

  final ProSalon salon;

  @override
  State<RandevularEkrani> createState() => _RandevularEkraniState();
}

class _RandevularEkraniState extends State<RandevularEkrani> {
  static const int _gun = 60;

  int _sekme = 0;
  List<TakvimKaydi>? _kayitlar;
  Object? _hata;
  int _sorgu = 0;
  final TextEditingController _arama = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kayitlar == null && _hata == null) {
      _yukle();
    }
  }

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final int sorgu = ++_sorgu;
    final DateTime simdi = DateTime.now();
    final DateTime bas = _sekme == 0 ? simdi : simdi.subtract(const Duration(days: _gun));
    final DateTime son = _sekme == 0 ? simdi.add(const Duration(days: _gun)) : simdi;
    try {
      final SupabaseClient i = await OturumKapsami.oku(context).istemciGerekli();
      final Object? sonuc = await i.rpc('salon_takvimi', params: <String, dynamic>{
        'p_salon': widget.salon.id,
        'p_bas': bas.toUtc().toIso8601String(),
        'p_son': son.toUtc().toIso8601String(),
      });
      if (!mounted || sorgu != _sorgu) {
        return;
      }
      List<TakvimKaydi> liste = sonuc is List
          ? sonuc.whereType<Map<String, dynamic>>().map(TakvimKaydi.json).where((TakvimKaydi k) => !k.blok).toList()
          : <TakvimKaydi>[];
      if (_sekme == 0) {
        liste = liste.where((TakvimKaydi k) => k.durum == 'bekliyor' || k.durum == 'onaylandi').toList();
      } else {
        liste = liste.reversed.toList();
      }
      setState(() {
        _kayitlar = liste;
        _hata = null;
      });
    } catch (hata) {
      if (mounted && sorgu == _sorgu) {
        setState(() => _hata = hata);
      }
    }
  }

  void _sekmeSec(int sekme) {
    if (sekme == _sekme) {
      return;
    }
    setState(() {
      _sekme = sekme;
      _kayitlar = null;
      _hata = null;
    });
    _yukle();
  }

  Future<void> _ayrinti(TakvimKaydi k) async {
    if (await randevuAyrintisiAc(context, k) && mounted) {
      await _yukle();
    }
  }

  static String _sade(String metin) => metin
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll(RegExp(r'[^a-z0-9çğöşü]'), '');

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Object? hata = _hata;
    final List<TakvimKaydi>? tum = _kayitlar;
    final String aranan = _sade(_arama.text);
    final List<TakvimKaydi>? liste = tum == null || aranan.isEmpty
        ? tum
        : tum
            .where((TakvimKaydi k) =>
                _sade(k.musteriAd ?? '').contains(aranan) || _sade(k.musteriTel ?? '').contains(aranan))
            .toList();
    final List<Widget> satirlar = <Widget>[];
    if (liste != null) {
      DateTime? onceki;
      for (final TakvimKaydi k in liste) {
        final DateTime g = DateTime(k.baslangic.year, k.baslangic.month, k.baslangic.day);
        if (onceki == null || g != onceki) {
          onceki = g;
          satirlar.add(
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: MaisonUstBaslik('${maisonGunBuyuk(g)} · ${g.day} ${maisonAyBuyuk(g)}'),
            ),
          );
        }
        satirlar.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TakvimSatiri(kayit: k, onTap: () => _ayrinti(k)),
          ),
        );
      }
    }
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
                  baslik: 'Randevular',
                ),
                const SizedBox(height: 16),
                MaisonSekmeSecici(
                  secenekler: const <String>['Yaklaşan', 'Geçmiş'],
                  secili: _sekme,
                  onSec: _sekmeSec,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _arama,
                  onChanged: (String _) => setState(() {}),
                  style: maisonGovde(15, renk: r.yazi),
                  decoration: InputDecoration(
                    hintText: 'Müşteri adı ya da telefon',
                    hintStyle: maisonGovde(14, renk: r.soluk),
                    prefixIcon: Icon(Icons.search, color: r.soluk),
                    filled: true,
                    fillColor: r.girdi,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: r.cizgi),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: r.cizgi),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (hata != null && tum == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MaisonHataKutusu(maisonHataMetni(hata), tekrar: _yukle),
                  )
                else if (liste == null)
                  const MaisonYukleniyor()
                else if (liste.isEmpty)
                  MaisonBosDurum(
                    ikon: _sekme == 0 ? Icons.event_available_outlined : Icons.history,
                    baslik: aranan.isNotEmpty
                        ? 'Eşleşen randevu yok'
                        : (_sekme == 0 ? 'Yaklaşan randevu yok' : 'Geçmiş randevu yok'),
                    aciklama: _sekme == 0
                        ? 'Önümüzdeki $_gun gün içindeki randevular burada görünür.'
                        : 'Son $_gun günün randevuları burada görünür.',
                  )
                else
                  ...satirlar,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
