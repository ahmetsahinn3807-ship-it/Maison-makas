import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'bildirim.dart';
import 'dil.dart';
import 'oturum.dart';

/// Uygulama kapalıyken gelen bildirimler (Firebase Cloud Messaging).
///
/// Telefonun bildirim jetonu hesaba kaydedilir; randevu alınınca ya da iptal edilince uygulama
/// sunucudaki bildirim fonksiyonunu ([fonksiyon]) çağırır, o da karşı tarafın telefonlarına gönderir.
/// Firebase kurulmamışsa (android/app/src/main/res/values/firebase.xml yoksa) sessizce devre dışı kalır;
/// uygulama açıkken canlı bildirimler (Realtime) yine çalışır.
class MaisonPush {
  MaisonPush._();

  static String? _uygulama;
  static String? _jeton;
  static SupabaseClient? _istemci;
  static StreamSubscription<String>? _yenileme;
  static bool _dilDinleniyor = false;

  /// Bu telefon uzaktan bildirim alabiliyor mu (jeton hesaba kaydedildi mi)?
  static bool get etkin => _jeton != null;

  /// Supabase'teki bildirim fonksiyonunun adı (kaynak: supabase/functions/randevu-bildirimi/index.ts).
  /// Panelden kurulurken Supabase bu adı verdi; ad sonradan değiştirilemiyor.
  static const String fonksiyon = 'smart-function';

  /// Uygulama şu an ekranda mı? Ekrandayken Firebase bildirimi göstermez; uygulama kendi gösterir.
  static bool get onde => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static bool get _destekli => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Giriş yapılınca çağrılır: jetonu alır ve hesaba kaydeder. [uygulama]: 'musteri' ya da 'pro'.
  static Future<void> baslat({required SupabaseClient istemci, required String uygulama}) async {
    if (!_destekli) {
      return;
    }
    _istemci = istemci;
    _uygulama = uygulama;
    await MaisonBildirim.hazirla();
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      }
      final FirebaseMessaging fm = FirebaseMessaging.instance;
      final String? jeton = await fm.getToken().timeout(const Duration(seconds: 20));
      if (jeton == null) {
        return;
      }
      await _kaydet(jeton);
      _yenileme ??= fm.onTokenRefresh.listen((String yeni) => unawaited(_kaydet(yeni)));
      if (!_dilDinleniyor) {
        _dilDinleniyor = true;
        MaisonTercih.dil.addListener(_dilDegisti);
      }
    } catch (hata) {
      debugPrint('MAISON: uzaktan bildirim kurulamadı: $hata');
    }
  }

  static void _dilDegisti() {
    final String? jeton = _jeton;
    if (jeton != null) {
      unawaited(_kaydet(jeton));
    }
  }

  static Future<void> _kaydet(String jeton) async {
    final SupabaseClient? i = _istemci;
    final String? uygulama = _uygulama;
    if (i == null || uygulama == null || i.auth.currentUser == null) {
      return;
    }
    try {
      await i.rpc('bildirim_jetonu_kaydet', params: <String, dynamic>{
        'p_jeton': jeton,
        'p_uygulama': uygulama,
        'p_platform': 'android',
        'p_dil': MaisonTercih.dil.value.name,
      });
      _jeton = jeton;
    } catch (hata) {
      debugPrint('MAISON: bildirim jetonu kaydedilemedi: $hata');
    }
  }

  /// Çıkıştan hemen önce: bu telefona artık o hesabın bildirimleri gelmesin.
  static Future<void> cikisOncesi() async {
    final String? jeton = _jeton;
    final SupabaseClient? i = _istemci;
    _jeton = null;
    if (jeton == null || i == null) {
      return;
    }
    try {
      await i.rpc('bildirim_jetonu_sil', params: <String, dynamic>{'p_jeton': jeton}).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Bağlantı yoksa jeton sunucuda kalır; 90 gün yenilenmezse kendiliğinden silinir.
    }
  }

  /// Randevu alındı ya da iptal edildi: karşı tarafa bildirim gönderilsin. Hata uygulamayı durdurmaz.
  static Future<void> olayBildir(SupabaseClient istemci, String randevuId) async {
    try {
      await istemci.functions
          .invoke(fonksiyon, body: <String, dynamic>{'randevu': randevuId})
          .timeout(const Duration(seconds: 20));
    } catch (hata) {
      debugPrint('MAISON: randevu bildirimi gönderilemedi: $hata');
    }
  }
}

/// Oturum açılınca uzaktan bildirimi başlatır. Uygulamanın kökünde bir kez kurulur.
class MaisonPushBaglayici {
  MaisonPushBaglayici(this.oturum, this.uygulama) {
    oturum.addListener(_degisti);
    _degisti();
  }

  final MaisonOturum oturum;
  final String uygulama;
  String? _kullanici;

  void _degisti() {
    final SupabaseClient? i = oturum.istemci;
    final String? id = oturum.kullanici?.id;
    if (i == null || id == null || !oturum.girisli) {
      _kullanici = null;
      return;
    }
    if (id == _kullanici) {
      return;
    }
    _kullanici = id;
    unawaited(MaisonPush.baslat(istemci: i, uygulama: uygulama));
  }

  void kapat() => oturum.removeListener(_degisti);
}
