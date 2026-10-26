import 'package:flutter/material.dart';

import 'bilesenler.dart';
import 'dil.dart';
import 'oturum.dart';
import 'renkler.dart';
import 'tema.dart';
import 'yasal.dart';

/// E-posta ve şifreyle giriş / hesap oluşturma. İki uygulama da kullanır.
///
/// Başarılı olunca kök sayfaya döner; kök sayfa oturuma bakarak doğru ekranı açar.
class MaisonGirisEkrani extends StatefulWidget {
  const MaisonGirisEkrani({
    super.key,
    required this.oturum,
    this.kayitModu = false,
    this.ustBaslik = 'MAISON MAKAS',
    this.girisAciklama,
    this.kayitAciklama,
  });

  final MaisonOturum oturum;
  final bool kayitModu;
  final String ustBaslik;
  /// Verilmezse müşteri uygulamasının metni (seçili dilde).
  final String? girisAciklama;
  final String? kayitAciklama;

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
      return dl('Adını ve soyadını yaz.', 'Enter your first and last name.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_eposta.text.trim())) {
      return dl('Geçerli bir e-posta adresi yaz.', 'Enter a valid email address.');
    }
    if (_kayit && _sifre.text.length < 8) {
      return dl('Şifre en az 8 karakter olmalı.', 'The password must be at least 8 characters.');
    }
    if (!_kayit && _sifre.text.isEmpty) {
      return dl('Şifreni yaz.', 'Enter your password.');
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
                  etiket: dl('Geri', 'Back'),
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 28),
              MaisonUstBaslik(widget.ustBaslik, renk: r.vurgu),
              const SizedBox(height: 10),
              Text(
                _kayit ? dl('Hesap oluştur', 'Create account') : dl('Hoş geldin', 'Welcome'),
                style: maisonBaslik(46, renk: r.yazi, yukseklik: 1.02),
              ),
              const SizedBox(height: 10),
              Text(
                _kayit
                    ? widget.kayitAciklama ??
                        dl(
                          'Birkaç saniyede hesabını oluştur; randevuların telefon değişse de seninle kalsın.',
                          'Create your account in seconds; your bookings stay with you even if you change phones.',
                        )
                    : widget.girisAciklama ??
                        dl(
                          'Randevularını ve favori ustalarını tek yerden yönet.',
                          'Manage your bookings and favourite barbers in one place.',
                        ),
                style: maisonGovde(15, renk: r.soluk, yukseklik: 1.5),
              ),
              const SizedBox(height: 26),
              MaisonSekmeSecici(
                secenekler: <String>[dl('Giriş', 'Sign in'), dl('Yeni hesap', 'New account')],
                secili: _kayit ? 1 : 0,
                onSec: _modDegistir,
              ),
              const SizedBox(height: 22),
              if (_kayit) ...<Widget>[
                MaisonAlan(
                  etiket: dl('AD SOYAD', 'FULL NAME'),
                  kontrol: _ad,
                  ipucu: dl('Adın ve soyadın', 'Your first and last name'),
                  otomatik: const <String>[AutofillHints.name],
                  eylem: TextInputAction.next,
                  buyukHarf: TextCapitalization.words,
                  enFazla: 80,
                ),
                const SizedBox(height: 16),
              ],
              MaisonAlan(
                etiket: dl('E-POSTA', 'EMAIL'),
                kontrol: _eposta,
                ipucu: dl('ornek@eposta.com', 'name@example.com'),
                klavye: TextInputType.emailAddress,
                otomatik: const <String>[AutofillHints.email],
                eylem: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: dl('ŞİFRE', 'PASSWORD'),
                kontrol: _sifre,
                ipucu: _kayit ? dl('En az 8 karakter', 'At least 8 characters') : dl('Şifren', 'Your password'),
                gizli: !_sifreGorunur,
                otomatik: <String>[_kayit ? AutofillHints.newPassword : AutofillHints.password],
                eylem: TextInputAction.done,
                gonder: (_) => _gonder(),
                sonek: IconButton(
                  tooltip: _sifreGorunur ? dl('Şifreyi gizle', 'Hide password') : dl('Şifreyi göster', 'Show password'),
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
                      : Text(_kayit ? dl('Hesabımı oluştur', 'Create my account') : dl('Giriş yap', 'Sign in')),
                ),
              ),
              const SizedBox(height: 22),
              const MaisonOnayNotu(),
            ],
          ),
        ),
      ),
    );
  }
}
