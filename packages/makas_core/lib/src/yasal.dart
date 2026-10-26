import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;

import 'dil.dart';
import 'renkler.dart';
import 'tema.dart';

/// Yasal metinlerin yayımlandığı site (GitHub Pages, depodaki docs/ klasörü).
const String maisonSiteAdresi = 'https://ahmetsahinn3807-ship-it.github.io/Maison-makas/';

/// Sitedeki belgeler. İngilizcesi olmayanlar (KVKK) Türkçe açılır.
enum MaisonBelge {
  gizlilik('gizlilik.html', 'privacy.html'),
  kosullar('kosullar.html', 'terms.html'),
  kvkk('kvkk.html', 'kvkk.html'),
  hesapSilme('hesap-silme.html', 'delete-account.html');

  const MaisonBelge(this._tr, this._en);

  final String _tr;
  final String _en;

  Uri get adres => Uri.parse('$maisonSiteAdresi${MaisonTercih.ingilizce ? _en : _tr}');

  String get ad {
    switch (this) {
      case MaisonBelge.gizlilik:
        return dl('Gizlilik politikası', 'Privacy policy');
      case MaisonBelge.kosullar:
        return dl('Kullanım şartları', 'Terms of use');
      case MaisonBelge.kvkk:
        return dl('KVKK aydınlatma metni', 'KVKK notice (Turkish)');
      case MaisonBelge.hesapSilme:
        return dl('Hesap ve veri silme', 'Account and data deletion');
    }
  }
}

/// Belgeyi tarayıcıda açar; açılamazsa false.
Future<bool> maisonBelgeAc(MaisonBelge belge) async {
  try {
    return await launchUrl(belge.adres, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<void> _ac(BuildContext context, MaisonBelge belge) async {
  final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
  if (!await maisonBelgeAc(belge)) {
    mesaj.showSnackBar(SnackBar(content: Text(dl('Sayfa açılamadı.', 'The page could not be opened.'))));
  }
}

/// Ayarlar ekranı için: gizlilik, şartlar ve KVKK bağlantıları.
class MaisonBelgeBaglantilari extends StatelessWidget {
  const MaisonBelgeBaglantilari({super.key});

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final List<MaisonBelge> belgeler = <MaisonBelge>[MaisonBelge.gizlilik, MaisonBelge.kosullar, MaisonBelge.kvkk];
    return Container(
      decoration: BoxDecoration(
        color: r.kart,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: r.cizgi),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < belgeler.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, thickness: 1, color: r.cizgi),
            InkWell(
              onTap: () => _ac(context, belgeler[i]),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(belgeler[i].ad, style: maisonGovde(15, renk: r.yazi, yukseklik: 1.3)),
                    ),
                    Icon(Icons.open_in_new, size: 18, color: r.soluk),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Giriş ekranının altı için: "Devam ederek … kabul etmiş olursun" ve iki bağlantı.
class MaisonOnayNotu extends StatelessWidget {
  const MaisonOnayNotu({super.key});

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final TextStyle baglanti = maisonGovde(12, renk: r.vurgu, yukseklik: 1.4, kalinlik: FontWeight.w600);
    return Column(
      children: <Widget>[
        Text(
          dl(
            'Devam ederek Kullanım Şartları\'nı kabul etmiş ve Gizlilik Politikası\'nı okumuş olursun.',
            'By continuing you accept the Terms of Use and confirm you have read the Privacy Policy.',
          ),
          textAlign: TextAlign.center,
          style: maisonGovde(12, renk: r.soluk, yukseklik: 1.6),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () => _ac(context, MaisonBelge.kosullar),
              child: Text(MaisonBelge.kosullar.ad, style: baglanti),
            ),
            TextButton(
              onPressed: () => _ac(context, MaisonBelge.gizlilik),
              child: Text(MaisonBelge.gizlilik.ad, style: baglanti),
            ),
          ],
        ),
      ],
    );
  }
}
