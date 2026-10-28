# WireGuard tunnel library binds native code (libwg-go) by class and method
# name over JNI, so R8 must not rename or strip it.
-keep class com.wireguard.** { *; }
-keep class billion.group.wireguard_flutter.** { *; }

# Flutter references Play Core only for deferred components, which this app
# does not use.
-dontwarn com.google.android.play.core.**
