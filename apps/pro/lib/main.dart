import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

import 'ekranlar/pro_acilis.dart';
import 'ekranlar/pro_baslangic.dart';

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
  runApp(MakasProUygulamasi(oturum: MaisonOturum(istemci)));
}

/// Makas Pro — salon sahipleri ve ustalar için işletme uygulaması.
class MakasProUygulamasi extends StatelessWidget {
  const MakasProUygulamasi({super.key, required this.oturum});

  final MaisonOturum oturum;

  @override
  Widget build(BuildContext context) {
    return OturumKapsami(
      oturum: oturum,
      child: MaterialApp(
        title: 'Makas Pro',
        debugShowCheckedModeBanner: false,
        theme: maisonTemasi(MaisonPalet.ivoire),
        home: const ProKapi(),
      ),
    );
  }
}

/// Giriş yapılmışsa salon akışını, yapılmamışsa tanıtımı gösterir.
class ProKapi extends StatelessWidget {
  const ProKapi({super.key});

  @override
  Widget build(BuildContext context) {
    final MaisonOturum oturum = OturumKapsami.of(context);
    if (!oturum.girisli) {
      return const ProAcilis();
    }
    final String anahtar = oturum.kullanici?.id ?? 'oturum';
    return ProBaslangic(key: ValueKey<String>(anahtar));
  }
}
