# Flutter ProGuard 规则（小体积 APK 优化）
# 配合 R8 fullMode + isMinifyEnabled + isShrinkResources

# ===== Flutter 核心（仅保留必要的入口类）=====
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.platform.** { *; }

# ===== 保持应用入口点 =====
-keep class com.example.todo.MainActivity { *; }

# ===== Hive (本地持久化) - 仅保留下划线开头的适配器字段 =====
-keep class com.example.todo.** { *; }
-keep class * extends com.example.todo.** { *; }
-keepattributes *Annotation*

# ===== Audio Players（仅保持必要的回调接口）=====
-keep class com.ryanheise.audioplayers.** { *; }

# ===== 移除日志（release 构建）=====
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# ===== 移除无用 Kotlin 相关 =====
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
    static void checkExpressionValueIsNotNull(java.lang.Object, java.lang.String);
    static void checkNotNullExpressionValue(java.lang.Object, java.lang.String);
    static void checkReturnedValueIsNotNull(java.lang.Object, java.lang.String, java.lang.String);
}

# ===== 允许 R8 优化移除未使用的枚举成员 =====
-allowaccessmodification
-repackageclasses
-optimizationpasses 5

# ===== 移除调试相关信息源文件名和行号 =====
-keepattributes InnerClasses,Signature
-renamesourcefileattribute SourceFile

# ===== 移除 Kotlin 元数据注解（减小 DEX 体积）=====
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-dontwarn kotlin.**

# ===== Gson（如果运行时用到）=====
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ===== 保持序列化/反序列化不被混淆破坏 =====
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# ===== URL Launcher =====
-keep class io.flutter.plugins.urllauncher.** { *; }
