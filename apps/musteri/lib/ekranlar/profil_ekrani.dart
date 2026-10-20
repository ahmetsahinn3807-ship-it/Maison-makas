import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

/// Profilim: kapak, avatar, ad ve iletişim bilgileri.
/// Kapak ve profil fotoğrafı yükleme 19. adımda gelir.
class ProfilEkrani extends StatefulWidget {
  const ProfilEkrani({
    super.key,
    required this.menuAc,
    required this.gorunumeGit,
    required this.ayarlaraGit,
  });

  final VoidCallback menuAc;
  final VoidCallback gorunumeGit;
  final VoidCallback ayarlaraGit;

  @override
  State<ProfilEkrani> createState() => _ProfilEkraniState();
}

class _ProfilEkraniState extends State<ProfilEkrani> {
  final TextEditingController _ad = TextEditingController();
  final TextEditingController _telefon = TextEditingController();
  String? _doldurulanProfil;
  bool _kaydediliyor = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _doldur(OturumKapsami.of(context));
  }

  @override
  void dispose() {
    _ad.dispose();
    _telefon.dispose();
    super.dispose();
  }

  /// Profil ilk geldiğinde alanları bir kez doldurur.
  void _doldur(MaisonOturum oturum) {
    final Map<String, dynamic>? profil = oturum.profil;
    final Object? id = profil?['id'];
    if (profil == null || id is! String || id == _doldurulanProfil) {
      return;
    }
    _doldurulanProfil = id;
    _ad.text = oturum.adSoyad;
    final Object? tel = profil['telefon'];
    _telefon.text = tel is String ? tel : '';
  }

  Future<void> _kaydet() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    final String ad = _ad.text.trim();
    final String tel = _telefon.text.trim();
    if (ad.length < 2) {
      mesaj.showSnackBar(const SnackBar(content: Text('Adını ve soyadını yaz.')));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _kaydediliyor = true);
    try {
      await oturum.profilGuncelle(<String, dynamic>{
        'ad_soyad': ad,
        'telefon': tel.isEmpty ? null : tel,
      });
      mesaj.showSnackBar(const SnackBar(content: Text('Bilgilerin kaydedildi.')));
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    } finally {
      if (mounted) {
        setState(() => _kaydediliyor = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final MaisonOturum oturum = OturumKapsami.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        SizedBox(
          height: 170 + 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              const Positioned(left: 0, right: 0, top: 0, child: MaisonKapak(yukseklik: 170)),
              Positioned(
                left: 20,
                top: 12,
                child: MaisonYuvarlakDugme(
                  ikon: Icons.menu,
                  etiket: 'Menüyü aç',
                  zemin: r.zemin.withValues(alpha: 0.6),
                  onTap: widget.menuAc,
                ),
              ),
              Positioned(
                right: 20,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: r.zemin.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Kapak fotoğrafı yakında',
                    style: maisonGovde(12, renk: r.soluk, kalinlik: FontWeight.w500, yukseklik: 1.2),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: 170 - 46,
                child: MaisonAvatar(basHarfler: oturum.basHarfler, boyut: 96),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                oturum.adSoyad.isEmpty ? 'Profilim' : oturum.adSoyad,
                style: maisonBaslik(32, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
              ),
              const SizedBox(height: 4),
              Text(oturum.eposta ?? '', style: maisonGovde(14, renk: r.soluk, yukseklik: 1.3)),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  color: r.kart,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: r.cizgi),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Bilgilerim', style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
                    const SizedBox(height: 14),
                    MaisonAlan(
                      etiket: 'AD SOYAD',
                      kontrol: _ad,
                      ipucu: 'Adın ve soyadın',
                      buyukHarf: TextCapitalization.words,
                      eylem: TextInputAction.next,
                      enFazla: 80,
                    ),
                    const SizedBox(height: 14),
                    MaisonAlan(
                      etiket: 'TELEFON',
                      kontrol: _telefon,
                      ipucu: '05xx xxx xx xx',
                      klavye: TextInputType.phone,
                      otomatik: const <String>[AutofillHints.telephoneNumber],
                      eylem: TextInputAction.done,
                      enFazla: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Telefonun yalnız randevu aldığın salonlara görünür.',
                      style: maisonGovde(12, renk: r.soluk, yukseklik: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _kaydediliyor ? null : _kaydet,
                        child: Text(_kaydediliyor ? 'Kaydediliyor…' : 'Kaydet'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _BaglantiSatiri(ikon: Icons.palette_outlined, etiket: 'Görünüm', onTap: widget.gorunumeGit),
              _BaglantiSatiri(ikon: Icons.tune, etiket: 'Ayarlar ve destek', onTap: widget.ayarlaraGit),
            ],
          ),
        ),
      ],
    );
  }
}

class _BaglantiSatiri extends StatelessWidget {
  const _BaglantiSatiri({required this.ikon, required this.etiket, required this.onTap});

  final IconData ikon;
  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
        child: Row(
          children: <Widget>[
            Icon(ikon, color: r.soluk, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(etiket, style: maisonGovde(15, renk: r.yazi, yukseklik: 1.2))),
            Icon(Icons.chevron_right, color: r.soluk),
          ],
        ),
      ),
    );
  }
}
