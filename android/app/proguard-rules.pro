# ============================================================
# Muskaan Minigame — ProGuard / R8 Rules
# ============================================================

# ── Flutter Engine ──────────────────────────────────────────
# Flutter communicates with native code via JNI; keep the
# engine's public interface intact.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Google ML Kit (Face Detection) ──────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ── Google Mobile Ads (AdMob) ───────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# ── CameraX (camera_android_camerax) ───────────────────────
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ── SQLite (sqlite3_flutter_libs) ───────────────────────────
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# ── Permission Handler ──────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ── General Android ─────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Suppress common warnings ───────────────────────────────
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**

