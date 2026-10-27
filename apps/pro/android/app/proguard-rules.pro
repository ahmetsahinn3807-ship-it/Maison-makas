# Maison Makas: R8 küçültmesi açıkken korunacak sınıflar.
# Flutter eklentileri açılışta yansıma (reflection) ile kaydedilir (GeneratedPluginRegistrant).
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class com.llfbandit.app_links.** { *; }
# Zamanlanmış randevu hatırlatmaları Gson ile saklanır; model sınıfları adlarıyla kalmalı.
-keep class com.dexterous.** { *; }
# Firebase bildirim eklentisi (arka planda gelen mesajlar).
-keep class io.flutter.plugins.firebase.** { *; }
# Flutter motorunun isteğe bağlı Play Core bağımlılığı uygulamada yok; R8 uyarısı derlemeyi durdurmasın.
-dontwarn com.google.android.play.core.**
