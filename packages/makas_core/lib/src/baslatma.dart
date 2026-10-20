import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show FlutterAuthClientOptions, LocalStorage, Supabase, SupabaseClient;

import 'supabase_ayar.dart';

/// Sunucu bağlantısını kurma denemesinin sonucu.
@immutable
class MaisonBaslatma {
  const MaisonBaslatma({this.istemci, this.hata});

  /// Kurulan istemci; kurulamadıysa null.
  final SupabaseClient? istemci;

  /// Bağlantı kurulurken çıkan hata (ekranda ayrıntı olarak gösterilir).
  final String? hata;
}

/// Supabase'i başlatır. Hiçbir durumda uygulamayı durdurmaz:
/// hata olursa ayrıntısını [MaisonBaslatma.hata] içinde döndürür.
Future<MaisonBaslatma> maisonSupabaseBaslat() async {
  final String oturumAnahtari = 'sb-${Uri.parse(MaisonSupabase.url).host.split('.').first}-auth-token';
  try {
    await Supabase.initialize(
      url: MaisonSupabase.url,
      publishableKey: MaisonSupabase.publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: MaisonYerelDepo(oturumAnahtari),
        // Giriş yalnız e-posta ve şifreyle; bağlantıdan oturum açma henüz yok.
        detectSessionInUri: false,
      ),
    ).timeout(const Duration(seconds: 10));
    return MaisonBaslatma(istemci: Supabase.instance.client);
  } catch (hata, iz) {
    debugPrint('MAISON: Supabase başlatılamadı: $hata');
    debugPrint('$iz');
    // Başlatma yarıda kaldıysa istemci yine de kurulmuş olabilir; onunla devam edilir.
    SupabaseClient? kurtarilan;
    try {
      kurtarilan = Supabase.instance.client;
    } catch (_) {
      kurtarilan = null;
    }
    return MaisonBaslatma(istemci: kurtarilan, hata: '${hata.runtimeType}: $hata');
  }
}

/// Oturumu cihazda (SharedPreferences) saklar. Cihaz deposu açılamazsa
/// uygulama durmasın diye oturumu bellekte tutar; [sorun] nedenini saklar.
class MaisonYerelDepo extends LocalStorage {
  MaisonYerelDepo(this.anahtar);

  final String anahtar;
  SharedPreferences? _tercihler;
  String? _bellek;

  /// Cihaz deposu açılamadıysa nedeni; sorun yoksa null.
  static String? sorun;

  @override
  Future<void> initialize() async {
    try {
      _tercihler = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      sorun = null;
    } catch (hata) {
      _tercihler = null;
      sorun = '${hata.runtimeType}: $hata';
      debugPrint('MAISON: Cihaz deposu açılamadı, oturum bellekte tutulacak: $hata');
    }
  }

  @override
  Future<bool> hasAccessToken() async {
    final SharedPreferences? t = _tercihler;
    if (t != null) {
      try {
        return t.containsKey(anahtar);
      } catch (_) {
        // Bellekteki değere bakılır.
      }
    }
    return _bellek != null;
  }

  @override
  Future<String?> accessToken() async {
    final SharedPreferences? t = _tercihler;
    if (t != null) {
      try {
        return t.getString(anahtar);
      } catch (_) {
        // Bellekteki değer döner.
      }
    }
    return _bellek;
  }

  @override
  Future<void> removePersistedSession() async {
    _bellek = null;
    try {
      await _tercihler?.remove(anahtar);
    } catch (_) {
      // Cihaz deposu yoksa yapılacak bir şey yok.
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    _bellek = persistSessionString;
    try {
      await _tercihler?.setString(anahtar, persistSessionString);
    } catch (_) {
      // Oturum bellekte kalır; uygulama kapanınca yeniden giriş gerekir.
    }
  }
}
