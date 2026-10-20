import 'package:flutter/material.dart';

import 'amblem.dart';
import 'renkler.dart';
import 'tema.dart';

/// 44 × 44 çerçeveli yuvarlak düğme (menü, geri, bildirim).
class MaisonYuvarlakDugme extends StatelessWidget {
  const MaisonYuvarlakDugme({
    super.key,
    required this.ikon,
    required this.etiket,
    this.onTap,
    this.nokta = false,
    this.zemin,
  });

  final IconData ikon;
  final String etiket;
  final VoidCallback? onTap;

  /// Sağ üstte küçük vurgu noktası (yeni bildirim).
  final bool nokta;

  /// Kapak fotoğrafı üstünde kullanıldığında yarı saydam zemin.
  final Color? zemin;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Semantics(
      button: true,
      label: etiket,
      child: Material(
        color: zemin ?? Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: r.cizgi)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(ikon, size: 20, color: r.yazi),
                if (nokta)
                  Positioned(
                    top: 10,
                    right: 11,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: r.vurgu,
                        shape: BoxShape.circle,
                        border: Border.all(color: r.zemin, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük, aralıklı büyük harf etiket (ör. YAKLAŞAN RANDEVU).
class MaisonUstBaslik extends StatelessWidget {
  const MaisonUstBaslik(this.metin, {super.key, this.renk});

  final String metin;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Text(
      metin,
      style: maisonGovde(
        11,
        renk: renk ?? r.soluk,
        kalinlik: FontWeight.w600,
        yukseklik: 1.2,
        aralik: 1.9,
      ),
    );
  }
}

/// Bölüm başlığı ve sağında isteğe bağlı bağlantı ("Tümü").
class MaisonBolumBasligi extends StatelessWidget {
  const MaisonBolumBasligi(this.baslik, {super.key, this.baglanti, this.onBaglanti});

  final String baslik;
  final String? baglanti;
  final VoidCallback? onBaglanti;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? b = baglanti;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            baslik,
            style: maisonBaslik(25, renk: r.yazi, kalinlik: FontWeight.w600),
          ),
        ),
        if (b != null)
          TextButton(
            onPressed: onBaglanti,
            child: Text(b, style: maisonGovde(13, renk: r.vurgu, kalinlik: FontWeight.w500)),
          ),
      ],
    );
  }
}

/// Etiketli metin alanı.
class MaisonAlan extends StatelessWidget {
  const MaisonAlan({
    super.key,
    required this.etiket,
    required this.kontrol,
    this.ipucu,
    this.klavye,
    this.gizli = false,
    this.otomatik,
    this.eylem,
    this.gonder,
    this.buyukHarf = TextCapitalization.none,
    this.sonek,
    this.enFazla,
  });

  final String etiket;
  final TextEditingController kontrol;
  final String? ipucu;
  final TextInputType? klavye;
  final bool gizli;
  final Iterable<String>? otomatik;
  final TextInputAction? eylem;
  final ValueChanged<String>? gonder;
  final TextCapitalization buyukHarf;
  final Widget? sonek;
  final int? enFazla;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final OutlineInputBorder kenar = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: r.cizgi),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MaisonUstBaslik(etiket),
        const SizedBox(height: 8),
        TextField(
          controller: kontrol,
          keyboardType: klavye,
          obscureText: gizli,
          autocorrect: !gizli,
          enableSuggestions: !gizli,
          autofillHints: otomatik,
          textInputAction: eylem,
          onSubmitted: gonder,
          textCapitalization: buyukHarf,
          maxLength: enFazla,
          style: maisonGovde(16, renk: r.yazi, yukseklik: 1.3),
          cursorColor: r.vurgu,
          decoration: InputDecoration(
            hintText: ipucu,
            hintStyle: maisonGovde(16, renk: r.soluk, yukseklik: 1.3),
            filled: true,
            fillColor: r.girdi,
            counterText: '',
            suffixIcon: sonek,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: kenar,
            enabledBorder: kenar,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: r.vurgu, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

/// İki ya da daha fazla seçenekli hap biçimli sekme seçici.
class MaisonSekmeSecici extends StatelessWidget {
  const MaisonSekmeSecici({
    super.key,
    required this.secenekler,
    required this.secili,
    required this.onSec,
  });

  final List<String> secenekler;
  final int secili;
  final ValueChanged<int> onSec;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: r.girdi,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: r.cizgi),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < secenekler.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == secili,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSec(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == secili ? r.vurgu : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      secenekler[i],
                      style: maisonGovde(
                        14,
                        renk: i == secili ? r.vurguUstu : r.soluk,
                        kalinlik: i == secili ? FontWeight.w600 : FontWeight.w500,
                        yukseklik: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Boş durum: simge, başlık, açıklama ve isteğe bağlı düğme.
class MaisonBosDurum extends StatelessWidget {
  const MaisonBosDurum({
    super.key,
    required this.ikon,
    required this.baslik,
    required this.aciklama,
    this.dugme,
    this.onDugme,
  });

  final IconData ikon;
  final String baslik;
  final String aciklama;
  final String? dugme;
  final VoidCallback? onDugme;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? d = dugme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: r.vurguYumusak,
              border: Border.all(color: r.vurguCizgi),
            ),
            child: Icon(ikon, color: r.vurgu, size: 26),
          ),
          const SizedBox(height: 16),
          Text(baslik, textAlign: TextAlign.center, style: maisonBaslik(24, renk: r.yazi)),
          const SizedBox(height: 8),
          Text(
            aciklama,
            textAlign: TextAlign.center,
            style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
          ),
          if (d != null) ...<Widget>[
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onDugme, child: Text(d)),
          ],
        ],
      ),
    );
  }
}

/// Hata kutusu; isteğe bağlı "Tekrar dene".
class MaisonHataKutusu extends StatelessWidget {
  const MaisonHataKutusu(this.mesaj, {super.key, this.tekrar});

  final String mesaj;
  final VoidCallback? tekrar;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Color hataRengi = Theme.of(context).colorScheme.error;
    final VoidCallback? t = tekrar;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: hataRengi.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hataRengi.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: hataRengi, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(mesaj, style: maisonGovde(14, renk: r.yazi, yukseklik: 1.4)),
          ),
          if (t != null) TextButton(onPressed: t, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

/// Yükleniyor göstergesi.
class MaisonYukleniyor extends StatelessWidget {
  const MaisonYukleniyor({super.key});

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2, color: r.vurgu),
        ),
      ),
    );
  }
}

/// Tasarımdaki açma-kapama anahtarı.
class MaisonAnahtar extends StatelessWidget {
  const MaisonAnahtar({
    super.key,
    required this.deger,
    required this.onChanged,
    required this.etiket,
  });

  final bool deger;
  final ValueChanged<bool> onChanged;
  final String etiket;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Semantics(
      button: true,
      toggled: deger,
      label: etiket,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!deger),
        child: SizedBox(
          width: 52,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 28,
              padding: const EdgeInsets.all(3),
              alignment: deger ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: deger ? r.vurgu : r.cizgi,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: deger ? r.vurguUstu : r.soluk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fotoğraf yokken kapak alanı: sıcak zemin ve sağda çift kemer.
class MaisonKapak extends StatelessWidget {
  const MaisonKapak({super.key, this.yukseklik = 132, this.child});

  final double yukseklik;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return SizedBox(
      height: yukseklik,
      width: double.infinity,
      child: ColoredBox(
        color: r.kapak,
        child: CustomPaint(
          painter: KapakKemerBoyaci(renk: r.vurguCizgi),
          child: child,
        ),
      ),
    );
  }
}

/// Baş harfli yuvarlak avatar (fotoğraf yüklenene kadar).
class MaisonAvatar extends StatelessWidget {
  const MaisonAvatar({
    super.key,
    required this.basHarfler,
    this.boyut = 72,
    this.halkaRengi,
  });

  final String basHarfler;
  final double boyut;
  final Color? halkaRengi;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final double ic = boyut - 6;
    return Container(
      width: boyut,
      height: boyut,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, color: halkaRengi ?? r.zemin),
      child: Container(
        width: ic,
        height: ic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: r.kart,
          border: Border.all(color: r.vurgu, width: 1.5),
        ),
        child: Text(
          basHarfler,
          style: maisonBaslik(ic * 0.38, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.0),
        ),
      ),
    );
  }
}

/// Henüz yapılmamış bölümler için sayfa.
class MaisonYakindaEkrani extends StatelessWidget {
  const MaisonYakindaEkrani({
    super.key,
    required this.baslik,
    required this.ikon,
    this.aciklama,
  });

  final String baslik;
  final IconData ikon;
  final String? aciklama;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return Scaffold(
      backgroundColor: r.zemin,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: MaisonYuvarlakDugme(
                ikon: Icons.arrow_back,
                etiket: 'Geri',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: 24),
            Text(baslik, style: maisonBaslik(40, renk: r.yazi, yukseklik: 1.05)),
            const SizedBox(height: 40),
            MaisonBosDurum(
              ikon: ikon,
              baslik: 'Çok yakında',
              aciklama: aciklama ?? 'Bu bölüm sıradaki adımlarda geliyor.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Sayfa başlığı satırı: solda yuvarlak düğme, ortada başlık, sağda isteğe bağlı düğme.
class MaisonUstSatir extends StatelessWidget {
  const MaisonUstSatir({
    super.key,
    required this.sol,
    this.baslik,
    this.sag,
  });

  final Widget sol;
  final String? baslik;
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? b = baslik;
    return Row(
      children: <Widget>[
        sol,
        Expanded(
          child: b == null
              ? const SizedBox.shrink()
              : Text(
                  b,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: maisonBaslik(22, renk: r.yazi, kalinlik: FontWeight.w600, aralik: 0.6),
                ),
        ),
        sag ?? const SizedBox(width: 44, height: 44),
      ],
    );
  }
}
