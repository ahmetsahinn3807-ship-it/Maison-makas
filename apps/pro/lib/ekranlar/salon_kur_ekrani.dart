import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, SupabaseClient, User;

import '../kisa_ad.dart';

/// Hesabında salon olmayan işletme sahibinin ilk adımı: salonun temel bilgileri.
class SalonKurEkrani extends StatefulWidget {
  const SalonKurEkrani({super.key, required this.onKuruldu});

  final VoidCallback onKuruldu;

  @override
  State<SalonKurEkrani> createState() => _SalonKurEkraniState();
}

class _SalonKurEkraniState extends State<SalonKurEkrani> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _ilce = TextEditingController();
  final TextEditingController _sehir = TextEditingController(text: 'İstanbul');
  final TextEditingController _telefon = TextEditingController();
  bool _benDeCalisiyorum = true;
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _ad.addListener(_adDegisti);
  }

  void _adDegisti() => setState(() {});

  @override
  void dispose() {
    _ad.removeListener(_adDegisti);
    _ad.dispose();
    _ilce.dispose();
    _sehir.dispose();
    _telefon.dispose();
    super.dispose();
  }

  Future<void> _kur() async {
    if (_kaydediliyor) {
      return;
    }
    final String ad = _ad.text.trim();
    if (ad.length < 2) {
      setState(() => _hata = 'Salonunun adını yaz.');
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final User? k = oturum.kullanici;
    if (k == null) {
      setState(() => _hata = 'Oturumun kapanmış. Çıkış yapıp yeniden giriş yap.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });

    final String kisaAd = kisaAdUret(ad);
    final math.Random rastgele = math.Random();
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      Map<String, dynamic>? salon;
      for (int deneme = 0; deneme < 4 && salon == null; deneme++) {
        final String aday = deneme == 0 ? kisaAd : kisaAdEki(kisaAd, 100 + rastgele.nextInt(900));
        try {
          salon = await i
              .from('salonlar')
              .insert(<String, dynamic>{
                'sahip_id': k.id,
                'ad': ad,
                'kisa_ad': aday,
                'ilce': _ilce.text.trim().isEmpty ? null : _ilce.text.trim(),
                'sehir': _sehir.text.trim().isEmpty ? null : _sehir.text.trim(),
                'telefon': _telefon.text.trim().isEmpty ? null : _telefon.text.trim(),
              })
              .select()
              .single();
        } on PostgrestException catch (hata) {
          if (hata.code != '23505') {
            rethrow;
          }
        }
      }
      final Map<String, dynamic>? kurulan = salon;
      if (kurulan == null) {
        throw const MaisonHata('Bu adla bir salon kısa adı bulunamadı. Adı biraz değiştirip dene.');
      }
      if (_benDeCalisiyorum) {
        final String ustaAdi = oturum.adSoyad.isEmpty ? 'Ben' : oturum.adSoyad;
        await i.from('ustalar').insert(<String, dynamic>{
          'salon_id': kurulan['id'],
          'kullanici_id': k.id,
          'ad': ustaAdi,
          'unvan': 'Salon sahibi',
          'sira': 0,
        });
      }
      if (!mounted) {
        return;
      }
      widget.onKuruldu();
    } catch (hata) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hata = maisonHataMetni(hata);
        _kaydediliyor = false;
      });
    }
  }

  Future<void> _cikis() async {
    await OturumKapsami.oku(context).cikisYap();
  }

  /// Usta, salon sahibinden aldığı kodla ekibe katılır.
  Future<void> _davetKoduGir() async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool? katildi = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.kart,
      showDragHandle: true,
      builder: (BuildContext context) => const _DavetKoduFormu(),
    );
    if (katildi == true && mounted) {
      widget.onKuruldu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String onizleme = _ad.text.trim().isEmpty ? 'salonunun-adi' : kisaAdUret(_ad.text);
    final String? hata = _hata;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(MaisonPalet.ivoire),
      child: Scaffold(
        backgroundColor: r.zemin,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: <Widget>[
              Row(
                children: <Widget>[
                  MaisonAmblem(renk: r.vurgu, zemin: r.zemin, genislik: 30),
                  const Spacer(),
                  TextButton(onPressed: _cikis, child: const Text('Çıkış yap')),
                ],
              ),
              const SizedBox(height: 22),
              MaisonUstBaslik('MAKAS PRO · 1. ADIM', renk: r.vurgu),
              const SizedBox(height: 10),
              Text('Salonunu kur', style: maisonBaslik(44, renk: r.yazi, yukseklik: 1.02)),
              const SizedBox(height: 10),
              Text(
                'Önce temel bilgiler. Hizmetleri, ustaları ve çalışma saatlerini sonraki adımda ekleyeceksin.',
                style: maisonGovde(15, renk: r.soluk, yukseklik: 1.5),
              ),
              const SizedBox(height: 26),
              MaisonAlan(
                etiket: 'SALON ADI',
                kontrol: _ad,
                ipucu: 'Örn. Maison Ahmet',
                buyukHarf: TextCapitalization.words,
                eylem: TextInputAction.next,
                enFazla: 80,
              ),
              const SizedBox(height: 8),
              Text(
                'Web randevu sayfan: …/s/$onizleme',
                style: maisonGovde(12, renk: r.soluk, yukseklik: 1.4),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: MaisonAlan(
                      etiket: 'İLÇE',
                      kontrol: _ilce,
                      ipucu: 'Sancaktepe',
                      buyukHarf: TextCapitalization.words,
                      eylem: TextInputAction.next,
                      enFazla: 60,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MaisonAlan(
                      etiket: 'ŞEHİR',
                      kontrol: _sehir,
                      buyukHarf: TextCapitalization.words,
                      eylem: TextInputAction.next,
                      enFazla: 60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: 'SALON TELEFONU',
                kontrol: _telefon,
                ipucu: '0216 xxx xx xx',
                klavye: TextInputType.phone,
                eylem: TextInputAction.done,
                enFazla: 20,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                decoration: BoxDecoration(
                  color: r.kart,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: r.cizgi),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Ben de müşteri alıyorum',
                            style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                          ),
                          Text(
                            'Seni de usta olarak ekleriz; kendi takvimin olur.',
                            style: maisonGovde(13, renk: r.soluk, yukseklik: 1.35),
                          ),
                        ],
                      ),
                    ),
                    MaisonAnahtar(
                      deger: _benDeCalisiyorum,
                      etiket: 'Ben de müşteri alıyorum',
                      onChanged: (bool deger) => setState(() => _benDeCalisiyorum = deger),
                    ),
                  ],
                ),
              ),
              if (hata != null) ...<Widget>[
                const SizedBox(height: 16),
                MaisonHataKutusu(hata),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _kur,
                  child: _kaydediliyor
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: r.vurguUstu),
                        )
                      : const Text('Salonu oluştur'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Salonun taslak olarak açılır; hazır olunca Ayarlar\'dan yayına alırsın.',
                textAlign: TextAlign.center,
                style: maisonGovde(12, renk: r.soluk, yukseklik: 1.5),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: r.kart,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: r.cizgi),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Bir salonda usta mısın?',
                      style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Salon kurmana gerek yok. Salon sahibinden aldığın davet koduyla ekibe katıl; '
                      'kendi randevularını burada görürsün.',
                      style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _kaydediliyor ? null : _davetKoduGir,
                        icon: const Icon(Icons.key_outlined, size: 18),
                        label: const Text('Davet kodum var'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Davet kodunu alır ve ekibe katılır; başarılıysa true ile kapanır.
class _DavetKoduFormu extends StatefulWidget {
  const _DavetKoduFormu();

  @override
  State<_DavetKoduFormu> createState() => _DavetKoduFormuState();
}

class _DavetKoduFormuState extends State<_DavetKoduFormu> {
  final TextEditingController _kod = TextEditingController();
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  Future<void> _katil() async {
    final String kod = _kod.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (kod.length != 8) {
      setState(() => _hata = 'Kod 8 karakter olmalı (ör. ABCD-EFGH).');
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      await i.rpc('usta_davetini_kabul_et', params: <String, dynamic>{'p_kod': kod});
      gezgin.pop(true);
    } catch (hata) {
      if (mounted) {
        setState(() {
          _gonderiliyor = false;
          _hata = maisonHataMetni(hata);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? hata = _hata;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Davet kodu', style: maisonBaslik(28, renk: r.yazi, kalinlik: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Salon sahibinin Makas Pro > Ekip ekranından oluşturup sana gönderdiği kodu yaz.',
                style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _kod,
                autofocus: true,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 9,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                ],
                onSubmitted: (String _) => _katil(),
                style: maisonBaslik(32, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1, aralik: 3),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'ABCD-EFGH',
                  hintStyle: maisonBaslik(32, renk: r.cizgi, kalinlik: FontWeight.w600, yukseklik: 1.1, aralik: 3),
                  filled: true,
                  fillColor: r.girdi,
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
              if (hata != null) ...<Widget>[
                const SizedBox(height: 12),
                MaisonHataKutusu(hata),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _gonderiliyor ? null : _katil,
                  child: Text(_gonderiliyor ? 'Katılıyor…' : 'Ekibe katıl'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
