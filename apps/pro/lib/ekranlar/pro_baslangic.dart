import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient, User;

import '../salon.dart';
import 'pro_kabuk.dart';
import 'salon_kur_ekrani.dart';

/// Giriş yapan kişinin salonunu bulur: sahibiyse ya da ustasıysa panele,
/// hiç salonu yoksa salon kurulumuna gider.
class ProBaslangic extends StatefulWidget {
  const ProBaslangic({super.key});

  @override
  State<ProBaslangic> createState() => _ProBaslangicState();
}

class _ProBaslangicState extends State<ProBaslangic> {
  Future<List<ProSalon>>? _gelecek;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gelecek ??= _yukle();
  }

  Future<List<ProSalon>> _yukle() async {
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final SupabaseClient? i = oturum.istemci;
    final User? k = oturum.kullanici;
    if (i == null || k == null) {
      return <ProSalon>[];
    }
    final List<Map<String, dynamic>> sahibi = await i
        .from('salonlar')
        .select()
        .eq('sahip_id', k.id)
        .order('olusturuldu', ascending: true);
    if (sahibi.isNotEmpty) {
      return sahibi.map((Map<String, dynamic> m) => ProSalon.json(m, sahibim: true)).toList();
    }
    final List<Map<String, dynamic>> ustasi = await i
        .from('ustalar')
        .select('salonlar(*)')
        .eq('kullanici_id', k.id)
        .eq('aktif', true);
    final List<ProSalon> salonlar = <ProSalon>[];
    for (final Map<String, dynamic> satir in ustasi) {
      final Object? s = satir['salonlar'];
      if (s is Map<String, dynamic>) {
        salonlar.add(ProSalon.json(s, sahibim: false));
      }
    }
    return salonlar;
  }

  void _yenile() {
    setState(() => _gelecek = _yukle());
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return FutureBuilder<List<ProSalon>>(
      future: _gelecek,
      builder: (BuildContext context, AsyncSnapshot<List<ProSalon>> durum) {
        if (durum.hasError) {
          return Scaffold(
            backgroundColor: r.zemin,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: MaisonHataKutusu(maisonHataMetni(durum.error!), tekrar: _yenile),
                ),
              ),
            ),
          );
        }
        final List<ProSalon>? salonlar = durum.data;
        if (salonlar == null) {
          return Scaffold(backgroundColor: r.zemin, body: const MaisonYukleniyor());
        }
        if (salonlar.isEmpty) {
          return SalonKurEkrani(onKuruldu: _yenile);
        }
        return ProKabuk(salon: salonlar.first, yenile: _yenile);
      },
    );
  }
}
