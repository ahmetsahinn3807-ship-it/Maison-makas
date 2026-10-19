import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';

import 'ekranlar/acilis_ekrani.dart';
import 'gorunum.dart';

void main() {
  runApp(const MaisonMakasUygulamasi());
}

class MaisonMakasUygulamasi extends StatefulWidget {
  const MaisonMakasUygulamasi({super.key});

  @override
  State<MaisonMakasUygulamasi> createState() => _MaisonMakasUygulamasiState();
}

class _MaisonMakasUygulamasiState extends State<MaisonMakasUygulamasi> {
  final Gorunum _gorunum = Gorunum();

  @override
  void dispose() {
    _gorunum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GorunumKapsami(
      gorunum: _gorunum,
      child: ListenableBuilder(
        listenable: _gorunum,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp(
            title: 'Maison Makas',
            debugShowCheckedModeBanner: false,
            theme: maisonTemasi(_gorunum.palet, vurgu: _gorunum.vurgu),
            home: const AcilisEkrani(),
          );
        },
      ),
    );
  }
}
