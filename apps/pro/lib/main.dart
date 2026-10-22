import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import 'ekranlar/pro_acilis.dart';
import 'ekranlar/pro_baslangic.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MaisonTercih.yukle();
  // Bağlantı kurulamasa da uygulama açılır; hata, giriş ekranında ayrıntısıyla gösterilir.
  final MaisonBaslatma baslatma = await maisonSupabaseBaslat();
  runApp(MakasProUygulamasi(oturum: MaisonOturum.baslatmadan(baslatma)));
}

/// Makas Pro — salon sahipleri ve ustalar için işletme uygulaması.
class MakasProUygulamasi extends StatefulWidget {
  const MakasProUygulamasi({super.key, required this.oturum});

  final MaisonOturum oturum;

  @override
  State<MakasProUygulamasi> createState() => _MakasProUygulamasiState();
}

class _MakasProUygulamasiState extends State<MakasProUygulamasi> {
  late final MaisonDilEsitleyici _dilEsitleyici;

  @override
  void initState() {
    super.initState();
    _dilEsitleyici = MaisonDilEsitleyici(widget.oturum);
  }

  @override
  void dispose() {
    _dilEsitleyici.kapat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OturumKapsami(
      oturum: widget.oturum,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[MaisonTercih.dil, MaisonTercih.koyu]),
        builder: (BuildContext context, Widget? child) {
          return MaterialApp(
            title: 'Makas Pro',
            debugShowCheckedModeBanner: false,
            theme: maisonTemasi(MaisonTercih.proPaleti),
            locale: MaisonTercih.dil.value.yerel,
            supportedLocales: MaisonTercih.desteklenenler,
            localizationsDelegates: MaisonTercih.yerellestirmeler,
            builder: (BuildContext context, Widget? child) => MaisonTercihKatmani(child: child),
            home: const ProKapi(),
          );
        },
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
