import 'package:flutter/material.dart';

import 'bilesenler.dart';
import 'dil.dart';
import 'oturum.dart';
import 'renkler.dart';
import 'tema.dart';

/// "Şifremi unuttum": e-postaya gelen kodla yeni şifre belirlenir. İki uygulama da kullanır.
///
/// 1. adım e-posta adresini alır ve kodu gönderir; 2. adım kodu ve yeni şifreyi alır.
/// Başarılı olunca oturum açılmış olur ve kök sayfaya dönülür.
class MaisonSifreSifirlamaEkrani extends StatefulWidget {
  const MaisonSifreSifirlamaEkrani({
    super.key,
    required this.oturum,
    this.eposta = '',
    this.ustBaslik = 'MAISON MAKAS',
  });

  final MaisonOturum oturum;
  final String eposta;
  final String ustBaslik;

  @override
  State<MaisonSifreSifirlamaEkrani> createState() => _MaisonSifreSifirlamaEkraniState();
}

class _MaisonSifreSifirlamaEkraniState extends State<MaisonSifreSifirlamaEkrani> {
  late final TextEditingController _eposta = TextEditingController(text: widget.eposta.trim());
  final TextEditingController _kod = TextEditingController();
  final TextEditingController _sifre = TextEditingController();
  bool _kodGonderildi = false;
  bool _gonderiliyor = false;
  bool _sifreGorunur = false;
  String? _hata;
  String? _bilgi;

  @override
  void dispose() {
    _eposta.dispose();
    _kod.dispose();
    _sifre.dispose();
    super.dispose();
  }

  bool get _epostaGecerli => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_eposta.text.trim());

  Future<void> _kodGonder() async {
    if (_gonderiliyor) {
      return;
    }
    if (!_epostaGecerli) {
      setState(() => _hata = dl('Geçerli bir e-posta adresi yaz.', 'Enter a valid email address.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _gonderiliyor = true;
      _hata = null;
      _bilgi = null;
    });
    try {
      await widget.oturum.sifreKoduGonder(_eposta.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _kodGonderildi = true;
        _gonderiliyor = false;
        _bilgi = dl(
          'Bu adrese ait bir hesap varsa sıfırlama kodu birkaç dakika içinde gelir. Gelen kutunu ve gereksiz (spam) klasörünü kontrol et.',
          'If an account exists for this address, a reset code will arrive within a few minutes. Check your inbox and spam folder.',
        );
      });
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

  Future<void> _sifreyiKaydet() async {
    if (_gonderiliyor) {
      return;
    }
    final String kod = _kod.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6,10}$').hasMatch(kod)) {
      setState(() => _hata = dl('E-postadaki kodu yaz.', 'Enter the code from the email.'));
      return;
    }
    if (_sifre.text.length < 8) {
      setState(() => _hata = dl('Şifre en az 8 karakter olmalı.', 'The password must be at least 8 characters.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      await widget.oturum.sifreyiYenile(eposta: _eposta.text, kod: kod, yeniSifre: _sifre.text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dl('Şifren yenilendi. Giriş yaptın.', 'Your password has been reset. You are signed in.'))),
      );
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

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? hata = _hata;
    final String? bilgi = _bilgi;
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
                dl('Şifreni yenile', 'Reset your password'),
                style: maisonBaslik(42, renk: r.yazi, yukseklik: 1.05),
              ),
              const SizedBox(height: 10),
              Text(
                _kodGonderildi
                    ? dl('E-postana gelen kodu ve yeni şifreni yaz.', 'Enter the code from your email and your new password.')
                    : dl(
                        'Hesabının e-posta adresini yaz; sana tek kullanımlık bir kod gönderelim.',
                        'Enter your account email and we will send you a one-time code.',
                      ),
                style: maisonGovde(15, renk: r.soluk, yukseklik: 1.5),
              ),
              const SizedBox(height: 26),
              MaisonAlan(
                etiket: dl('E-POSTA', 'EMAIL'),
                kontrol: _eposta,
                ipucu: dl('ornek@eposta.com', 'name@example.com'),
                klavye: TextInputType.emailAddress,
                otomatik: const <String>[AutofillHints.email],
                eylem: _kodGonderildi ? TextInputAction.next : TextInputAction.done,
                gonder: _kodGonderildi ? null : (_) => _kodGonder(),
              ),
              if (_kodGonderildi) ...<Widget>[
                const SizedBox(height: 16),
                MaisonAlan(
                  etiket: dl('KOD', 'CODE'),
                  kontrol: _kod,
                  ipucu: dl('E-postadaki kod', 'Code from the email'),
                  klavye: TextInputType.number,
                  otomatik: const <String>[AutofillHints.oneTimeCode],
                  eylem: TextInputAction.next,
                  enFazla: 12,
                ),
                const SizedBox(height: 16),
                MaisonAlan(
                  etiket: dl('YENİ ŞİFRE', 'NEW PASSWORD'),
                  kontrol: _sifre,
                  ipucu: dl('En az 8 karakter', 'At least 8 characters'),
                  gizli: !_sifreGorunur,
                  otomatik: const <String>[AutofillHints.newPassword],
                  eylem: TextInputAction.done,
                  gonder: (_) => _sifreyiKaydet(),
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
              ],
              if (bilgi != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(bilgi, style: maisonGovde(13, renk: r.soluk, yukseklik: 1.5)),
              ],
              if (hata != null) ...<Widget>[
                const SizedBox(height: 16),
                MaisonHataKutusu(hata),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _kodGonderildi ? _sifreyiKaydet : _kodGonder,
                  child: _gonderiliyor
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: r.vurguUstu),
                        )
                      : Text(_kodGonderildi ? dl('Yeni şifreyi kaydet', 'Save new password') : dl('Kod gönder', 'Send code')),
                ),
              ),
              if (_kodGonderildi) ...<Widget>[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _gonderiliyor ? null : _kodGonder,
                    child: Text(
                      dl('Kodu yeniden gönder', 'Send the code again'),
                      style: maisonGovde(13, renk: r.vurgu, kalinlik: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
