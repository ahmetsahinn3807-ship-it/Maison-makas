# Maison Makas: keep Flutter plugins when R8 is enabled.
# Plugins are registered at startup through reflection (GeneratedPluginRegistrant).
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class com.llfbandit.app_links.** { *; }
