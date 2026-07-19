# Flutter / R8
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Flutter plugin registrants (evita MissingPluginException en release)
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.PluginRegistry$PluginRegistrantCallback { *; }

# Atributos útiles para reflexión / serialización
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Play Core / deferred components (avisos frecuentes)
-dontwarn com.google.android.play.core.**

# Google Fonts / okhttp (dependencias transitivas)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# video_player / ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# url_launcher / webview auth
-keep class io.flutter.plugins.urllauncher.** { *; }
