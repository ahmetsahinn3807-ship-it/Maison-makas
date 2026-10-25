import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../salon.dart';
import 'salon_bilgileri_ekrani.dart';

/// Makas Pro ayarları: salonu yayına alma, çıkış ve hesap silme.
class ProAyarlar extends StatefulWidget {
  const ProAyarlar({super.key, required this.salon, required this.salonDegisti});

  final ProSalon salon;
  final VoidCallback salonDegisti;

  @override
  State<ProAyarlar> createState() => _ProAyarlarState();
}

class _ProAyarlarState extends State<ProAyarlar> {
  late bool _yayinda = widget.salon.yayinda;
  bool _isleniyor = false;

  Future<void> _yayinDegistir(bool yeni) async {
    final SupabaseClient? i = OturumKapsami.oku(context).istemci;
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    if (i == null) {
      return;
    }
    setState(() {
      _yayinda = yeni;
      _isleniyor = true;
    });
    try {
      await i.from('salonlar').update(<String, dynamic>{'yayinda': yeni}).eq('id', widget.salon.id);
      widget.salonDegisti();
      mesaj.showSnackBar(SnackBar(
        content: Text(yeni ? dl('Salonun yayında; müşteriler Keşfet\'te görür.', 'Your salon is live; customers can see it in Discover.') : dl('Salonun taslağa alındı.', 'Your salon is now a draft.')),
      ));
    } catch (hata) {
      if (mounted) {
        setState(() => _yayinda = !yeni);
      }
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    } finally {
      if (mounted) {
        setState(() => _isleniyor = false);
      }
    }
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
    final bool sahibim = widget.salon.sahibim;
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: r.kart,
          title: Text(
            sahibim ? dl('Hesabın ve salonun silinsin mi?', 'Delete your account and salon?') : dl('Hesabın silinsin mi?', 'Delete your account?'),
            style: maisonBaslik(26, renk: r.yazi),
          ),
          content: Text(
            sahibim
                ? dl('${widget.salon.ad}; ekibi, hizmetleri, çalışma saatleri ve randevu geçmişiyle '
                    'birlikte silinir. Yaklaşan randevu varsa önce onları iptal etmen gerekir. '
                    'Bu işlem geri alınamaz.', '${widget.salon.ad} is deleted together with its team, services, working hours and booking history. '
                        'If there are upcoming bookings you need to cancel them first. '
                        'This cannot be undone.')
                : dl('Hesabın silinir ve Makas Pro\'ya bu hesapla giremezsin. Salondaki usta kaydın '
                    've geçmiş randevular salon sahibinde kalır. Bu işlem geri alınamaz.', 'Your account is deleted and you can no longer sign in to Makas Pro with it. Your barber record '
                        'and past bookings stay with the salon owner. This cannot be undone.'),
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
      await oturum.hesabiSil(salonlarla: widget.salon.sahibim);
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
              baslik: dl('Ayarlar', 'Settings'),
            ),
            const SizedBox(height: 26),
            MaisonUstBaslik(dl('SALON', 'SALON')),
            const SizedBox(height: 12),
            Material(
              color: r.kart,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        SalonBilgileriEkrani(salon: widget.salon, salonDegisti: widget.salonDegisti),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  decoration: BoxDecoration(
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
                              dl('Salon bilgileri', 'Salon details'),
                              style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                            ),
                            Text(
                              dl('Tanıtım, adres, telefon, hazırlık ve iptal süresi', 'About, address, phone, preparation and cancellation time'),
                              style: maisonGovde(13, renk: r.soluk, yukseklik: 1.35),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: r.soluk),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
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
                          dl('Salon yayında', 'Salon is live'),
                          style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.3),
                        ),
                        Text(
                          widget.salon.sahibim
                              ? dl('Açıkken müşteriler salonunu Maison Makas\'ta görür.', 'When on, customers see your salon on Maison Makas.')
                              : dl('Bu ayarı yalnız salon sahibi değiştirebilir.', 'Only the salon owner can change this.'),
                          style: maisonGovde(13, renk: r.soluk, yukseklik: 1.35),
                        ),
                      ],
                    ),
                  ),
                  MaisonAnahtar(
                    deger: _yayinda,
                    etiket: dl('Salon yayında', 'Salon is live'),
                    onChanged: (bool yeni) {
                      if (!widget.salon.sahibim || _isleniyor) {
                        return;
                      }
                      _yayinDegistir(yeni);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              dl('Hizmet ve çalışma saati eklemeden yayına alırsan müşteriler salonunu görür ama henüz randevu alamaz.', 'If you publish before adding services and working hours, customers will see your salon but cannot book yet.'),
              style: maisonGovde(12, renk: r.soluk, yukseklik: 1.45),
            ),
            const SizedBox(height: 28),
            MaisonUstBaslik(dl('GÖRÜNÜM', 'APPEARANCE')),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: MaisonTercih.koyu,
              builder: (BuildContext context, bool koyu, Widget? _) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  decoration: BoxDecoration(
                    color: r.kart,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: r.cizgi),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.dark_mode_outlined, size: 20, color: r.soluk),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(dl('Koyu görünüm', 'Dark mode'), style: maisonGovde(15, renk: r.yazi, yukseklik: 1.2)),
                      ),
                      MaisonAnahtar(
                        deger: koyu,
                        etiket: dl('Koyu görünüm', 'Dark mode'),
                        onChanged: MaisonTercih.koyuAyarla,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            MaisonUstBaslik(dl('YAZI BOYUTU', 'TEXT SIZE')),
            const SizedBox(height: 12),
            const MaisonYaziBoyutuSecici(),
            const SizedBox(height: 18),
            MaisonUstBaslik(dl('DİL', 'LANGUAGE')),
            const SizedBox(height: 12),
            const MaisonDilSecici(),
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
            const SizedBox(height: 28),
            Center(
              child: Text(
                dl('Makas Pro · sürüm 0.8.0', 'Makas Pro · version 0.8.0'),
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
