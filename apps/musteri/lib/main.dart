import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import 'ekranlar/acilis_ekrani.dart';
import 'ekranlar/kabuk.dart';
import 'gorunum.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bağlantı kurulamasa da uygulama açılır; hata, giriş ekranında ayrıntısıyla gösterilir.
  await MaisonTercih.yukle();
  final MaisonBaslatma baslatma = await maisonSupabaseBaslat();
  runApp(MaisonMakasUygulamasi(oturum: MaisonOturum.baslatmadan(baslatma)));
}

class MaisonMakasUygulamasi extends StatefulWidget {
  const MaisonMakasUygulamasi({super.key, required this.oturum});

  final MaisonOturum oturum;

  @override
  State<MaisonMakasUygulamasi> createState() => _MaisonMakasUygulamasiState();
}

class _MaisonMakasUygulamasiState extends State<MaisonMakasUygulamasi> {
  late final Gorunum _gorunum = Gorunum(kaydet: _gorunumuKaydet);
  late final MaisonDilEsitleyici _dilEsitleyici;
  String? _uygulananKullanici;

  @override
  void initState() {
    super.initState();
    widget.oturum.addListener(_oturumDegisti);
    _oturumDegisti();
    _dilEsitleyici = MaisonDilEsitleyici(widget.oturum);
  }

  Future<void> _gorunumuKaydet(Map<String, dynamic> alanlar) async {
    if (widget.oturum.girisli) {
      await widget.oturum.profilGuncelle(alanlar);
    }
  }

  /// Hesaptaki görünüm ayarlarını oturum başına bir kez uygular.
  void _oturumDegisti() {
    if (!widget.oturum.girisli) {
      _uygulananKullanici = null;
      return;
    }
    final Map<String, dynamic>? profil = widget.oturum.profil;
    final Object? id = profil?['id'];
    if (profil != null && id is String && id != _uygulananKullanici) {
      _uygulananKullanici = id;
      _gorunum.uygula(profil['gorunum']);
    }
  }

  @override
  void dispose() {
    widget.oturum.removeListener(_oturumDegisti);
    _dilEsitleyici.kapat();
    _gorunum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OturumKapsami(
      oturum: widget.oturum,
      child: GorunumKapsami(
        gorunum: _gorunum,
        child: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[_gorunum, MaisonTercih.dil]),
          builder: (BuildContext context, Widget? child) {
            return MaterialApp(
              title: 'Maison Makas',
              debugShowCheckedModeBanner: false,
              theme: maisonTemasi(_gorunum.palet, vurgu: _gorunum.vurgu),
              locale: MaisonTercih.dil.value.yerel,
              supportedLocales: MaisonTercih.desteklenenler,
              localizationsDelegates: MaisonTercih.yerellestirmeler,
              builder: (BuildContext context, Widget? child) => MaisonTercihKatmani(child: child),
              home: const OturumKapisi(),
            );
          },
        ),
      ),
    );
  }
}

/// Giriş yapılmışsa ana kabuğu, yapılmamışsa açılışı gösterir.
class OturumKapisi extends StatelessWidget {
  const OturumKapisi({super.key});

  @override
  Widget build(BuildContext context) {
    final MaisonOturum oturum = OturumKapsami.of(context);
    return oturum.girisli ? const Kabuk() : const AcilisEkrani();
  }
}
