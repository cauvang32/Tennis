# ─── Flutter framework ──────────────────────────────────────────────────────
# Flutter's plugin registrant reflects into these classes; R8 must not
# strip or rename them, or platform channels stop resolving.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─── flutter_local_notifications ────────────────────────────────────────────
# The plugin uses Gson for serialising timezone + schedule config; its
# reflection-based deserialisation breaks if these are renamed/removed.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ─── flutter_secure_storage ─────────────────────────────────────────────────
# Tink is the underlying crypto library; Android Keystore + reflection
# paths in androidx.security.crypto must be preserved.
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ─── Kotlin (data classes, companion object access) ────────────────────────
-keepclassmembers class **$Companion {
    public static final ** INSTANCE;
}
