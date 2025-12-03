# ==================== 기본 Android 설정 ====================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exception
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ==================== 카카오 로그인 ====================
-keep class com.kakao.sdk.** { *; }
-keep interface com.kakao.sdk.** { *; }
-keepclassmembers class com.kakao.sdk.** { *; }
-dontwarn com.kakao.**

# ==================== 네이버 로그인 ====================
-keep class com.navercorp.nid.** { *; }
-keep interface com.navercorp.nid.** { *; }
-keepclassmembers class com.navercorp.nid.** { *; }
-dontwarn com.navercorp.**

# 네이버 로그인 OAuth 관련
-keep class com.nhn.android.** { *; }
-keep interface com.nhn.android.** { *; }
-keepclassmembers class com.nhn.android.** { *; }
-dontwarn com.nhn.android.**

# 네이버 로그인 Activity 보호
-keep class com.nhn.android.naverlogin.ui.** { *; }

# ==================== Firebase & Google 로그인 ====================
-keep class com.google.firebase.** { *; }
-keepclassmembers class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

-keep class com.google.android.gms.** { *; }
-keepclassmembers class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Play Services
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# ==================== Retrofit (카카오/네이버 내부 사용) ====================
-keep class retrofit2.** { *; }
-keepclassmembers class retrofit2.** { *; }
-dontwarn retrofit2.**

-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# ==================== Gson ====================
-keep class com.google.gson.** { *; }
-keepclassmembers class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Gson 모델 클래스 보호 (JSON 직렬화/역직렬화)
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation @interface com.google.gson.annotations.SerializedName

# ==================== OkHttp ====================
-keep class okhttp3.** { *; }
-keepclassmembers class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# OkHttp Platform
-keep class okhttp3.internal.platform.** { *; }

# ==================== Kotlin ====================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# ==================== 일반 규칙 ====================
# Enum 보호
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable 보호
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Serializable 보호
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Native 메서드 보호
-keepclasseswithmembernames class * {
    native <methods>;
}

# ==================== R8 최적화 제외 ====================
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify