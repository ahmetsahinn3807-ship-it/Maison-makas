import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'dil.dart';

/// Telefonun kendi bildirimleri: randevu hatırlatmaları (önceden zamanlanır) ve anlık uyarılar.
///
/// Sunucu gerekmez; zamanlanan bildirim uygulama kapalıyken de gelir. Bütün çağrılar hatayı yutar:
/// bildirim gösterilemese de uygulama çalışmaya devam eder (ör. testlerde ya da izin yokken).
class MaisonBildirim {
  MaisonBildirim._();

  static final FlutterLocalNotificationsPlugin _eklenti = FlutterLocalNotificationsPlugin();
  static Future<bool>? _hazir;

  static const String _ayarAnahtari = 'maison.bildirim.hatirlatma';

  /// Kanal adı seçili dilde; Android kanalın adını her bildirimde günceller.
  static NotificationDetails get _ayrinti => NotificationDetails(
        android: AndroidNotificationDetails(
          'randevu',
          dl('Randevular', 'Appointments'),
          channelDescription: dl(
            'Randevu hatırlatmaları, yeni randevular ve iptaller',
            'Appointment reminders, new bookings and cancellations',
          ),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  static bool get _destekli =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Eklentiyi bir kez hazırlar; izin istemez.
  static Future<bool> hazirla() => _hazir ??= _kur();

  static Future<bool> _kur() async {
    if (!_destekli) {
      return false;
    }
    try {
      final bool? sonuc = await _eklenti.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher_monochrome'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return sonuc ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Bildirim izni ister (Android 13+ ve iOS). Verildiyse true.
  static Future<bool> izinIste() async {
    if (!await hazirla()) {
      return false;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final bool? izin = await _eklenti
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        return izin ?? true;
      }
      final bool? izin = await _eklenti
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return izin ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hemen gösterir.
  static Future<void> goster({required int id, required String baslik, required String metin}) async {
    if (!await hazirla()) {
      return;
    }
    try {
      await _eklenti.show(id: id, title: baslik, body: metin, notificationDetails: _ayrinti);
    } catch (_) {
      // İzin yoksa ya da eklenti çalışmıyorsa bildirim gösterilmez.
    }
  }

  /// [zaman]da gösterilmek üzere zamanlar (geçmişteyse hiçbir şey yapmaz).
  static Future<void> zamanla({
    required int id,
    required DateTime zaman,
    required String baslik,
    required String metin,
  }) async {
    if (!zaman.isAfter(DateTime.now().add(const Duration(seconds: 30))) || !await hazirla()) {
      return;
    }
    try {
      await _eklenti.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(zaman.toUtc(), tz.UTC),
        notificationDetails: _ayrinti,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: baslik,
        body: metin,
      );
    } catch (_) {
      // Zamanlanamazsa hatırlatma gelmez; randevu yine geçerlidir.
    }
  }

  /// Zamanlanmış bütün bildirimleri kaldırır (gösterilmiş olanlara dokunmaz).
  static Future<void> zamanlananlariKaldir() async {
    if (!await hazirla()) {
      return;
    }
    try {
      await _eklenti.cancelAllPendingNotifications();
    } catch (_) {
      // Eklenti yoksa yapılacak bir şey yok.
    }
  }

  /// Randevu hatırlatmaları açık mı (varsayılan: açık)? Bu telefonda saklanır.
  static Future<bool> hatirlatmaAcik() async {
    try {
      final SharedPreferences ayar = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      return ayar.getBool(_ayarAnahtari) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> hatirlatmaAyarla(bool acik) async {
    try {
      final SharedPreferences ayar = await SharedPreferences.getInstance().timeout(const Duration(seconds: 4));
      await ayar.setBool(_ayarAnahtari, acik);
    } catch (_) {
      // Ayar saklanamazsa varsayılan (açık) kullanılır.
    }
  }
}
