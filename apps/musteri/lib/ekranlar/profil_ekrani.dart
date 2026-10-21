import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient, User;

/// Profilim: kapak ve profil fotoğrafı, ad ve iletişim bilgileri.
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

  /// Yüklenen fotoğraf: 'kapak' ya da 'avatar'; yoksa null.
  String? _yuklenen;

  static const double _kapakYuksekligi = 190;

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

  Future<void> _kapakDegistir() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    final String? eski = oturum.kapakUrl;
    final FotoIslemi? islem = await maisonFotoIslemiSor(
      context,
      baslik: 'Kapak fotoğrafı',
      kaldirilabilir: eski != null,
      odakAyarlanabilir: eski != null,
    );
    if (islem == null || !mounted) {
      return;
    }
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      final User? k = oturum.kullanici;
      if (k == null) {
        throw const MaisonHata('Önce giriş yapmalısın.');
      }
      if (islem == FotoIslemi.kaldir) {
        setState(() => _yuklenen = 'kapak');
        await oturum.profilGuncelle(<String, dynamic>{
          'kapak_url': null,
          'kapak_odak_x': 0.5,
          'kapak_odak_y': 0.5,
        });
        await maisonFotoSil(i, eski);
        mesaj.showSnackBar(const SnackBar(content: Text('Kapak fotoğrafı kaldırıldı.')));
        return;
      }
      if (islem == FotoIslemi.odak) {
        if (eski == null || !mounted) {
          return;
        }
        final Offset? odak = await maisonOdakSec(
          context,
          resim: NetworkImage(eski),
          baslangic: oturum.kapakOdak,
          oran: 390 / _kapakYuksekligi,
        );
        if (odak == null || !mounted) {
          return;
        }
        setState(() => _yuklenen = 'kapak');
        await oturum.profilGuncelle(<String, dynamic>{'kapak_odak_x': odak.dx, 'kapak_odak_y': odak.dy});
        return;
      }
      final SecilenFoto? foto = await maisonFotoSec(islem, FotoBoyu.kapak);
      if (foto == null || !mounted) {
        return;
      }
      final Offset? odak = await maisonOdakSec(
        context,
        resim: MemoryImage(foto.baytlar),
        oran: 390 / _kapakYuksekligi,
      );
      if (odak == null || !mounted) {
        return;
      }
      setState(() => _yuklenen = 'kapak');
      final String url = await maisonFotoYukle(i, kova: 'profil', klasor: k.id, ad: 'kapak', foto: foto);
      await oturum.profilGuncelle(<String, dynamic>{
        'kapak_url': url,
        'kapak_odak_x': odak.dx,
        'kapak_odak_y': odak.dy,
      });
      await maisonFotoSil(i, eski);
      mesaj.showSnackBar(const SnackBar(content: Text('Kapak fotoğrafın güncellendi.')));
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    } finally {
      if (mounted) {
        setState(() => _yuklenen = null);
      }
    }
  }

  Future<void> _avatarDegistir() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    final String? eski = oturum.avatarUrl;
    final FotoIslemi? islem = await maisonFotoIslemiSor(
      context,
      baslik: 'Profil fotoğrafı',
      kaldirilabilir: eski != null,
    );
    if (islem == null || islem == FotoIslemi.odak || !mounted) {
      return;
    }
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      final User? k = oturum.kullanici;
      if (k == null) {
        throw const MaisonHata('Önce giriş yapmalısın.');
      }
      if (islem == FotoIslemi.kaldir) {
        setState(() => _yuklenen = 'avatar');
        await oturum.profilGuncelle(<String, dynamic>{'avatar_url': null});
        await maisonFotoSil(i, eski);
        mesaj.showSnackBar(const SnackBar(content: Text('Profil fotoğrafı kaldırıldı.')));
        return;
      }
      final SecilenFoto? foto = await maisonFotoSec(islem, FotoBoyu.avatar);
      if (foto == null || !mounted) {
        return;
      }
      setState(() => _yuklenen = 'avatar');
      final String url = await maisonFotoYukle(i, kova: 'profil', klasor: k.id, ad: 'avatar', foto: foto);
      await oturum.profilGuncelle(<String, dynamic>{'avatar_url': url});
      await maisonFotoSil(i, eski);
      mesaj.showSnackBar(const SnackBar(content: Text('Profil fotoğrafın güncellendi.')));
    } catch (hata) {
      mesaj.showSnackBar(SnackBar(content: Text(maisonHataMetni(hata))));
    } finally {
      if (mounted) {
        setState(() => _yuklenen = null);
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
          height: _kapakYuksekligi + 62,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: MaisonKapak(
                  yukseklik: _kapakYuksekligi,
                  url: oturum.kapakUrl,
                  odak: oturum.kapakOdak,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: _kapakYuksekligi - 70,
                height: 70,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[r.zemin.withValues(alpha: 0), r.zemin],
                      ),
                    ),
                  ),
                ),
              ),
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
                child: Material(
                  color: r.zemin.withValues(alpha: 0.6),
                  shape: StadiumBorder(side: BorderSide(color: r.cizgi)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _yuklenen == null ? _kapakDegistir : null,
                    child: SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (_yuklenen == 'kapak')
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: r.vurgu),
                              )
                            else
                              Icon(Icons.photo_camera_outlined, size: 18, color: r.yazi),
                            const SizedBox(width: 8),
                            Text(
                              'Kapağı değiştir',
                              style: maisonGovde(13, renk: r.yazi, kalinlik: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                top: _kapakYuksekligi - 46,
                child: SizedBox(
                  width: 96 + 14,
                  height: 96 + 10,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      MaisonAvatar(basHarfler: oturum.basHarfler, boyut: 96, fotoUrl: oturum.avatarUrl),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Semantics(
                          button: true,
                          label: 'Profil fotoğrafını değiştir',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _yuklenen == null ? _avatarDegistir : null,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: r.vurgu,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: r.zemin, width: 2),
                                  ),
                                  child: _yuklenen == 'avatar'
                                      ? Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: CircularProgressIndicator(strokeWidth: 2, color: r.vurguUstu),
                                        )
                                      : Icon(Icons.photo_camera_outlined, size: 16, color: r.vurguUstu),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
