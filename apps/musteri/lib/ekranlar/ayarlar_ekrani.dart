import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import '../dil.dart';
import '../gorunum.dart';

/// Ayarlar ve destek: dil, çıkış, hesap silme ve gizlilik.
class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  bool _isleniyor = false;

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
          title: Text('Hesabın silinsin mi?', style: maisonBaslik(26, renk: r.yazi)),
          content: Text(
            'Profilin, favorilerin ve stil fotoğrafların kalıcı olarak silinir; '
            'yaklaşan randevuların iptal edilir. Salonların geçmiş kayıtlarında adın görünmez. '
            'Bu işlem geri alınamaz.',
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Hesabımı sil',
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
      mesaj.showSnackBar(const SnackBar(content: Text('Hesabın silindi.')));
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
    final Gorunum gorunum = GorunumKapsami.of(context);
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
                etiket: 'Geri',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              baslik: 'Ayarlar ve destek',
            ),
            const SizedBox(height: 26),
            const MaisonUstBaslik('DİL'),
            const SizedBox(height: 12),
            MaisonSekmeSecici(
              secenekler: <String>[for (final Dil d in Dil.values) d.kod],
              secili: Dil.values.indexOf(gorunum.dil),
              onSec: (int i) => gorunum.dilSec(Dil.values[i]),
            ),
            const SizedBox(height: 8),
            Text(
              'Şimdilik açılış ekranı çevriliyor; uygulamanın tamamı 23. adımda gelecek.',
              style: maisonGovde(12, renk: r.soluk, yukseklik: 1.4),
            ),
            const SizedBox(height: 28),
            const MaisonUstBaslik('HESAP'),
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
                child: const Text('Çıkış yap'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _isleniyor ? null : _hesabiSil,
              child: Text(
                'Hesabımı sil',
                style: maisonGovde(14, renk: Theme.of(context).colorScheme.error, kalinlik: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 22),
            const MaisonUstBaslik('GİZLİLİK'),
            const SizedBox(height: 10),
            Text(
              'Telefonun ve randevu geçmişin yalnız randevu aldığın salonlara görünür. '
              'Hesabını istediğin an buradan silebilirsin; kişisel verilerin de silinir.',
              style: maisonGovde(14, renk: r.soluk, yukseklik: 1.55),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Maison Makas · sürüm 0.5.0',
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
