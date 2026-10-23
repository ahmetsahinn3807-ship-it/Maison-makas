import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../hatirlatma.dart';
import '../veri.dart';

/// Ayarlar ve destek: dil, bildirimler, çıkış, hesap silme ve gizlilik.
class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  bool _isleniyor = false;

  /// Randevu hatırlatmaları; okunana kadar null.
  bool? _hatirlatma;

  @override
  void initState() {
    super.initState();
    MaisonBildirim.hatirlatmaAcik().then((bool acik) {
      if (mounted) {
        setState(() => _hatirlatma = acik);
      }
    });
  }

  Future<void> _hatirlatmaDegistir(bool acik) async {
    final Veri veri = Veri.of(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    setState(() => _hatirlatma = acik);
    await MaisonBildirim.hatirlatmaAyarla(acik);
    if (acik && !await MaisonBildirim.izinIste()) {
      mesaj.showSnackBar(
        SnackBar(content: Text(dl('Bildirim izni kapalı. Telefonun Ayarlar > Bildirimler bölümünden açabilirsin.', 'Notifications are turned off. You can turn them on in your phone\'s Settings > Notifications.'))),
      );
    }
    await RandevuHatirlatici.esitle(veri);
  }

  Future<void> _cikisYap() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    setState(() => _isleniyor = true);
    try {
      await oturum.cikisYap();
    } finally {
      gezgin.popUntil((Route<dynamic> rota) => rota.isFirst);
    }
  }

  Future<void> _hesabiSil() async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Color hataRengi = Theme.of(context).colorScheme.error;
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: r.kart,
          title: Text(dl('Hesabın silinsin mi?', 'Delete your account?'), style: maisonBaslik(26, renk: r.yazi)),
          content: Text(
            dl('Profilin, favorilerin ve stil fotoğrafların kalıcı olarak silinir; '
            'yaklaşan randevuların iptal edilir. Salonların geçmiş kayıtlarında adın görünmez. '
            'Bu işlem geri alınamaz.', 'Your profile, favourites and style photos are permanently deleted; '
                'upcoming bookings are cancelled. Your name will not appear in salons\' past records. '
                'This cannot be undone.'),
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(dl('Vazgeç', 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                dl('Hesabımı sil', 'Delete my account'),
                style: maisonGovde(14, renk: hataRengi, kalinlik: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    if (onay != true || !mounted) {
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    setState(() => _isleniyor = true);
    try {
      await oturum.hesabiSil();
      gezgin.popUntil((Route<dynamic> rota) => rota.isFirst);
      mesaj.showSnackBar(SnackBar(content: Text(dl('Hesabın silindi.', 'Your account has been deleted.'))));
    } catch (hata) {
      if (mounted) {
        setState(() => _isleniyor = false);
      }
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final MaisonOturum oturum = OturumKapsami.of(context);
    return Scaffold(
      backgroundColor: r.zemin,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            MaisonUstSatir(
              sol: MaisonYuvarlakDugme(
                ikon: Icons.arrow_back,
                etiket: dl('Geri', 'Back'),
                onTap: () => Navigator.of(context).maybePop(),
              ),
              baslik: dl('Ayarlar ve destek', 'Settings and support'),
            ),
            const SizedBox(height: 26),
            MaisonUstBaslik(dl('DİL', 'LANGUAGE')),
            const SizedBox(height: 12),
            const MaisonDilSecici(),
            const SizedBox(height: 28),
            MaisonUstBaslik(dl('BİLDİRİMLER', 'NOTIFICATIONS')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
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
                          dl('Randevu hatırlatmaları', 'Appointment reminders'),
                          style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                        ),
                        Text(
                          dl('Randevudan 24 saat ve 2 saat önce bu telefona bildirim gelir.', 'You get a notification on this phone 24 hours and 2 hours before.'),
                          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.35),
                        ),
                      ],
                    ),
                  ),
                  MaisonAnahtar(
                    deger: _hatirlatma ?? true,
                    etiket: dl('Randevu hatırlatmaları', 'Appointment reminders'),
                    onChanged: (bool yeni) {
                      if (_hatirlatma != null) {
                        _hatirlatmaDegistir(yeni);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            MaisonUstBaslik(dl('HESAP', 'ACCOUNT')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: r.kart,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: r.cizgi),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.alternate_email, color: r.soluk, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      oturum.eposta ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: maisonGovde(15, renk: r.yazi, yukseklik: 1.2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _isleniyor ? null : _cikisYap,
                child: Text(dl('Çıkış yap', 'Sign out')),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _isleniyor ? null : _hesabiSil,
              child: Text(
                dl('Hesabımı sil', 'Delete my account'),
                style: maisonGovde(14, renk: Theme.of(context).colorScheme.error, kalinlik: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 22),
            MaisonUstBaslik(dl('GİZLİLİK', 'PRIVACY')),
            const SizedBox(height: 10),
            Text(
              dl('Telefonun ve randevu geçmişin yalnız randevu aldığın salonlara görünür. '
              'Hesabını istediğin an buradan silebilirsin; kişisel verilerin de silinir.', 'Your phone number and booking history are visible only to salons you book with. '
                  'You can delete your account here at any time; your personal data is deleted too.'),
              style: maisonGovde(14, renk: r.soluk, yukseklik: 1.55),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                dl('Maison Makas · sürüm 0.7.1', 'Maison Makas · version 0.7.1'),
                style: maisonGovde(12, renk: r.soluk, yukseklik: 1.2),
              ),
            ),
            if (oturum.tanilama != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                oturum.tanilama!,
                textAlign: TextAlign.center,
                style: maisonGovde(11, renk: r.soluk, yukseklik: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
