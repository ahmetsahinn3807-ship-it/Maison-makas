import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

import 'ekranlar/acilis_ekrani.dart';
import 'ekranlar/kabuk.dart';
import 'gorunum.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SupabaseClient? istemci;
  try {
    await Supabase.initialize(
      url: MaisonSupabase.url,
      publishableKey: MaisonSupabase.publishableKey,
    );
    istemci = Supabase.instance.client;
  } catch (_) {
    istemci = null;
  }
  runApp(MaisonMakasUygulamasi(oturum: MaisonOturum(istemci)));
}

class MaisonMakasUygulamasi extends StatefulWidget {
  const MaisonMakasUygulamasi({super.key, required this.oturum});

  final MaisonOturum oturum;

  @override
  State<MaisonMakasUygulamasi> createState() => _MaisonMakasUygulamasiState();
}

class _MaisonMakasUygulamasiState extends State<MaisonMakasUygulamasi> {
  late final Gorunum _gorunum = Gorunum(kaydet: _gorunumuKaydet);
  String? _uygulananKullanici;

  @override
  void initState() {
    super.initState();
    widget.oturum.addListener(_oturumDegisti);
    _oturumDegisti();
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
      _gorunum.uygula(profil['gorunum'], profil['dil']);
    }
  }

  @override
  void dispose() {
    widget.oturum.removeListener(_oturumDegisti);
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
          listenable: _gorunum,
          builder: (BuildContext context, Widget? child) {
            return MaterialApp(
              title: 'Maison Makas',
              debugShowCheckedModeBanner: false,
              theme: maisonTemasi(_gorunum.palet, vurgu: _gorunum.vurgu),
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
