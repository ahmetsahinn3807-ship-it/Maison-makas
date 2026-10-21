import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../salon.dart';

/// Salonun tanıtımı, iletişim bilgileri ve randevu kuralları.
class SalonBilgileriEkrani extends StatefulWidget {
  const SalonBilgileriEkrani({super.key, required this.salon, required this.salonDegisti});

  final ProSalon salon;
  final VoidCallback salonDegisti;

  @override
  State<SalonBilgileriEkrani> createState() => _SalonBilgileriEkraniState();
}

class _SalonBilgileriEkraniState extends State<SalonBilgileriEkrani> {
  static const List<int> _tamponlar = <int>[0, 5, 10, 15, 20, 30];
  static const List<int> _iptaller = <int>[0, 60, 120, 180, 360, 720, 1440];

  final TextEditingController _ad = TextEditingController();
  final TextEditingController _aciklama = TextEditingController();
  final TextEditingController _telefon = TextEditingController();
  final TextEditingController _adres = TextEditingController();
  final TextEditingController _ilce = TextEditingController();
  final TextEditingController _sehir = TextEditingController();
  int _tampon = 0;
  int _iptal = 180;
  bool _yuklendi = false;
  bool _kaydediliyor = false;
  Object? _yuklemeHatasi;
  String? _uyari;

  bool get _sahibim => widget.salon.sahibim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_yuklendi && _yuklemeHatasi == null) {
      _yukle();
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    _telefon.dispose();
    _adres.dispose();
    _ilce.dispose();
    _sehir.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final SupabaseClient i = await OturumKapsami.oku(context).istemciGerekli();
      final Map<String, dynamic> m = await i
          .from('salonlar')
          .select('ad, aciklama, telefon, adres, ilce, sehir, tampon_dk, ucretsiz_iptal_dk')
          .eq('id', widget.salon.id)
          .single();
      if (!mounted) {
        return;
      }
      setState(() {
        _ad.text = (m['ad'] as String?) ?? '';
        _aciklama.text = (m['aciklama'] as String?) ?? '';
        _telefon.text = (m['telefon'] as String?) ?? '';
        _adres.text = (m['adres'] as String?) ?? '';
        _ilce.text = (m['ilce'] as String?) ?? '';
        _sehir.text = (m['sehir'] as String?) ?? '';
        _tampon = (m['tampon_dk'] as num?)?.toInt() ?? 0;
        _iptal = (m['ucretsiz_iptal_dk'] as num?)?.toInt() ?? 180;
        _yuklendi = true;
        _yuklemeHatasi = null;
      });
    } catch (hata) {
      if (mounted) {
        setState(() => _yuklemeHatasi = hata);
      }
    }
  }

  String? _bos(TextEditingController k) {
    final String metin = k.text.trim();
    return metin.isEmpty ? null : metin;
  }

  Future<void> _kaydet() async {
    if (!_sahibim || _kaydediliyor) {
      return;
    }
    final String ad = _ad.text.trim();
    if (ad.length < 2) {
      setState(() => _uyari = 'Salonun adını yaz (en az 2 harf).');
      return;
    }
    if (_aciklama.text.trim().length > 1000) {
      setState(() => _uyari = 'Tanıtım en çok 1000 karakter olabilir.');
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _kaydediliyor = true;
      _uyari = null;
    });
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      final List<Map<String, dynamic>> satirlar = await i
          .from('salonlar')
          .update(<String, dynamic>{
            'ad': ad,
            'aciklama': _bos(_aciklama),
            'telefon': _bos(_telefon),
            'adres': _bos(_adres),
            'ilce': _bos(_ilce),
            'sehir': _bos(_sehir),
            'tampon_dk': _tampon,
            'ucretsiz_iptal_dk': _iptal,
          })
          .eq('id', widget.salon.id)
          .select('id');
      if (satirlar.isEmpty) {
        throw const MaisonHata('Değişiklik kaydedilemedi: bu salonu düzenleme yetkin yok.');
      }
      widget.salonDegisti();
      mesaj.showSnackBar(const SnackBar(content: Text('Salon bilgileri kaydedildi.')));
      gezgin.pop();
    } catch (hata) {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
          _uyari = maisonHataMetni(hata);
        });
      }
    }
  }

  String _iptalMetni(int dakika) {
    if (dakika == 0) {
      return 'Son ana kadar';
    }
    return dakika % 60 == 0 ? '${dakika ~/ 60} saat' : '$dakika dk';
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Object? yuklemeHatasi = _yuklemeHatasi;
    final String? uyari = _uyari;
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
                baslik: 'Salon bilgileri',
              ),
              const SizedBox(height: 18),
              if (yuklemeHatasi != null && !_yuklendi)
                MaisonHataKutusu(
                  maisonHataMetni(yuklemeHatasi),
                  tekrar: () {
                    setState(() => _yuklemeHatasi = null);
                    _yukle();
                  },
                )
              else if (!_yuklendi)
                const MaisonYukleniyor()
              else ...<Widget>[
                if (!_sahibim) ...<Widget>[
                  Text(
                    'Salon bilgilerini yalnız salon sahibi değiştirebilir.',
                    style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
                  ),
                  const SizedBox(height: 14),
                ],
                AbsorbPointer(
                  absorbing: !_sahibim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      MaisonAlan(
                        etiket: 'SALON ADI',
                        kontrol: _ad,
                        enFazla: 80,
                        buyukHarf: TextCapitalization.words,
                        eylem: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      const MaisonUstBaslik('TANITIM'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _aciklama,
                        minLines: 3,
                        maxLines: 7,
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        style: maisonGovde(15, renk: r.yazi, yukseklik: 1.5),
                        decoration: InputDecoration(
                          hintText: 'Müşterilerin vitrinde okuyacağı birkaç cümle: salonun tarzı, '
                              'öne çıkan hizmetler, otopark ya da ulaşım bilgisi…',
                          hintMaxLines: 4,
                          hintStyle: maisonGovde(14, renk: r.soluk, yukseklik: 1.45),
                          filled: true,
                          fillColor: r.girdi,
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: r.cizgi),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: r.cizgi),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: r.vurgu, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      MaisonAlan(
                        etiket: 'TELEFON',
                        kontrol: _telefon,
                        ipucu: '0216 xxx xx xx',
                        klavye: TextInputType.phone,
                        enFazla: 20,
                        eylem: TextInputAction.next,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Vitrindeki Ara ve Mesaj (WhatsApp) düğmeleri bu numarayı kullanır.',
                        style: maisonGovde(12, renk: r.soluk, yukseklik: 1.4),
                      ),
                      const SizedBox(height: 16),
                      MaisonAlan(
                        etiket: 'ADRES',
                        kontrol: _adres,
                        ipucu: 'Mahalle, cadde, no',
                        enFazla: 200,
                        buyukHarf: TextCapitalization.sentences,
                        eylem: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: MaisonAlan(
                              etiket: 'İLÇE',
                              kontrol: _ilce,
                              enFazla: 60,
                              buyukHarf: TextCapitalization.words,
                              eylem: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MaisonAlan(
                              etiket: 'ŞEHİR',
                              kontrol: _sehir,
                              enFazla: 60,
                              buyukHarf: TextCapitalization.words,
                              eylem: TextInputAction.done,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const MaisonUstBaslik('İKİ RANDEVU ARASI HAZIRLIK'),
                      const SizedBox(height: 4),
                      Text(
                        'Bir randevu bitince ustanın bir sonrakine geçmeden önceki temizlik ve hazırlık payı.',
                        style: maisonGovde(12, renk: r.soluk, yukseklik: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final int t in _tamponlar)
                            ChoiceChip(
                              label: Text(t == 0 ? 'Yok' : '$t dk'),
                              selected: _tampon == t,
                              onSelected: (bool _) => setState(() => _tampon = t),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const MaisonUstBaslik('ÜCRETSİZ İPTAL'),
                      const SizedBox(height: 4),
                      Text(
                        'Müşteri randevusunu bu süreden daha geç iptal ederse "geç iptal" olarak işaretlenir.',
                        style: maisonGovde(12, renk: r.soluk, yukseklik: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final int d in _iptaller)
                            ChoiceChip(
                              label: Text(_iptalMetni(d)),
                              selected: _iptal == d,
                              onSelected: (bool _) => setState(() => _iptal = d),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (uyari != null) ...<Widget>[
                  const SizedBox(height: 16),
                  MaisonHataKutusu(uyari),
                ],
                if (_sahibim) ...<Widget>[
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _kaydediliyor ? null : _kaydet,
                      child: Text(_kaydediliyor ? 'Kaydediliyor…' : 'Kaydet'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
