import 'package:flutter/material.dart';

import 'bilesenler.dart';
import 'oturum.dart';
import 'renkler.dart';
import 'tema.dart';

/// E-posta ve şifreyle giriş / hesap oluşturma. İki uygulama da kullanır.
///
/// Başarılı olunca kök sayfaya döner; kök sayfa oturuma bakarak doğru ekranı açar.
class MaisonGirisEkrani extends StatefulWidget {
  const MaisonGirisEkrani({
    super.key,
    required this.oturum,
    this.kayitModu = false,
    this.ustBaslik = 'MAISON MAKAS',
    this.girisAciklama = 'Randevularını ve favori ustalarını tek yerden yönet.',
    this.kayitAciklama =
        'Birkaç saniyede hesabını oluştur; randevuların telefon değişse de seninle kalsın.',
  });

  final MaisonOturum oturum;
  final bool kayitModu;
  final String ustBaslik;
  final String girisAciklama;
  final String kayitAciklama;

  @override
  State<MaisonGirisEkrani> createState() => _MaisonGirisEkraniState();
}

class _MaisonGirisEkraniState extends State<MaisonGirisEkrani> {
  late bool _kayit = widget.kayitModu;
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _eposta = TextEditingController();
  final TextEditingController _sifre = TextEditingController();
  bool _gonderiliyor = false;
  bool _sifreGorunur = false;
  String? _hata;

  @override
  void dispose() {
    _ad.dispose();
    _eposta.dispose();
    _sifre.dispose();
    super.dispose();
  }

  String? _dogrula() {
    if (_kayit && _ad.text.trim().length < 2) {
      return 'Adını ve soyadını yaz.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_eposta.text.trim())) {
      return 'Geçerli bir e-posta adresi yaz.';
    }
    if (_kayit && _sifre.text.length < 8) {
      return 'Şifre en az 8 karakter olmalı.';
    }
    if (!_kayit && _sifre.text.isEmpty) {
      return 'Şifreni yaz.';
    }
    return null;
  }

  Future<void> _gonder() async {
    if (_gonderiliyor) {
      return;
    }
    final String? sorun = _dogrula();
    if (sorun != null) {
      setState(() => _hata = sorun);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      if (_kayit) {
        await widget.oturum.kayitOl(
          adSoyad: _ad.text,
          eposta: _eposta.text,
          sifre: _sifre.text,
        );
      } else {
        await widget.oturum.girisYap(eposta: _eposta.text, sifre: _sifre.text);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((Route<dynamic> rota) => rota.isFirst);
    } catch (hata) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hata = maisonHataMetni(hata);
        _gonderiliyor = false;
      });
    }
  }

  void _modDegistir(int sira) {
    setState(() {
      _kayit = sira == 1;
      _hata = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? hata = _hata;
    return Scaffold(
      backgroundColor: r.zemin,
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: MaisonYuvarlakDugme(
                  ikon: Icons.arrow_back,
                  etiket: 'Geri',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 28),
              MaisonUstBaslik(widget.ustBaslik, renk: r.vurgu),
              const SizedBox(height: 10),
              Text(
                _kayit ? 'Hesap oluştur' : 'Hoş geldin',
                style: maisonBaslik(46, renk: r.yazi, yukseklik: 1.02),
              ),
              const SizedBox(height: 10),
              Text(
                _kayit ? widget.kayitAciklama : widget.girisAciklama,
                style: maisonGovde(15, renk: r.soluk, yukseklik: 1.5),
              ),
              const SizedBox(height: 26),
              MaisonSekmeSecici(
                secenekler: const <String>['Giriş', 'Yeni hesap'],
                secili: _kayit ? 1 : 0,
                onSec: _modDegistir,
              ),
              const SizedBox(height: 22),
              if (_kayit) ...<Widget>[
                MaisonAlan(
                  etiket: 'AD SOYAD',
                  kontrol: _ad,
                  ipucu: 'Adın ve soyadın',
                  otomatik: const <String>[AutofillHints.name],
                  eylem: TextInputAction.next,
                  buyukHarf: TextCapitalization.words,
                  enFazla: 80,
                ),
                const SizedBox(height: 16),
              ],
              MaisonAlan(
                etiket: 'E-POSTA',
                kontrol: _eposta,
                ipucu: 'ornek@eposta.com',
                klavye: TextInputType.emailAddress,
                otomatik: const <String>[AutofillHints.email],
                eylem: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: 'ŞİFRE',
                kontrol: _sifre,
                ipucu: _kayit ? 'En az 8 karakter' : 'Şifren',
                gizli: !_sifreGorunur,
                otomatik: <String>[_kayit ? AutofillHints.newPassword : AutofillHints.password],
                eylem: TextInputAction.done,
                gonder: (_) => _gonder(),
                sonek: IconButton(
                  tooltip: _sifreGorunur ? 'Şifreyi gizle' : 'Şifreyi göster',
                  onPressed: () => setState(() => _sifreGorunur = !_sifreGorunur),
                  icon: Icon(
                    _sifreGorunur ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: r.soluk,
                    size: 20,
                  ),
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
                  onPressed: _gonder,
                  child: _gonderiliyor
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: r.vurguUstu),
                        )
                      : Text(_kayit ? 'Hesabımı oluştur' : 'Giriş yap'),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Devam ederek Kullanım Şartları\'nı ve Gizlilik Politikası\'nı kabul etmiş olursun.',
                textAlign: TextAlign.center,
                style: maisonGovde(12, renk: r.soluk, yukseklik: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
