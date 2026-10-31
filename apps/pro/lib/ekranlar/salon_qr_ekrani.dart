import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../randevu_baglantisi.dart';
import '../salon.dart';

/// Salonun randevu bağlantısının QR kodu. Müşteri okutunca salonun randevu sayfası açılır.
class SalonQrEkrani extends StatelessWidget {
  const SalonQrEkrani({super.key, required this.salon});

  final ProSalon salon;

  Future<void> _kopyala(BuildContext context, String baglanti) async {
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: baglanti));
    mesaj.showSnackBar(SnackBar(content: Text(dl('Bağlantı kopyalandı.', 'Link copied.'))));
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool hazir = salon.kisaAd.isNotEmpty;
    final String baglanti = hazir ? randevuBaglantisi(salon.kisaAd) : '';
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
              baslik: dl('Randevu QR kodu', 'Booking QR code'),
            ),
            const SizedBox(height: 22),
            Text(
              dl(
                'Bu kodu okutan müşteri salonunun randevu sayfasını açar. Tabela, ayna ya da kasanın üstüne asabilirsin.',
                'A customer who scans this code opens your booking page. Put it on a sign, a mirror or the till.',
              ),
              style: maisonGovde(14, renk: r.soluk, yukseklik: 1.45),
            ),
            const SizedBox(height: 18),
            if (!hazir)
              MaisonHataKutusu(
                dl(
                  'Önce salon bilgilerini kaydet. Kısa adres oluşunca QR kodu hazır olur.',
                  'Save your salon details first. The QR code is ready once the short address is set.',
                ),
              )
            else ...<Widget>[
              if (!salon.yayinda) ...<Widget>[
                MaisonHataKutusu(
                  dl(
                    'Salon taslakta. Müşteriler randevu sayfasını göremez. Ayarlar\'dan salonu yayına al.',
                    'Your salon is a draft. Customers cannot open the booking page. Turn the salon live in Settings.',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: baglanti,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                salon.ad,
                textAlign: TextAlign.center,
                style: maisonBaslik(24, renk: r.yazi),
              ),
              const SizedBox(height: 12),
              SelectableText(
                baglanti,
                textAlign: TextAlign.center,
                style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: () => _kopyala(context, baglanti),
                  child: Text(dl('Bağlantıyı kopyala', 'Copy link')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
