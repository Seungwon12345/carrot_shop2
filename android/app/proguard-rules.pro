########################################
# 1. [필수] 네이버 로그인 SDK 보호 규칙 (이게 없으면 로그인 안됨!)
########################################
-keep class com.flutter_naver_login.** { *; }
-keep public class com.nhn.android.naverlogin.** { *; }
-keep public class com.navercorp.nid.** { *; }
-dontwarn com.nhn.android.naverlogin.**
-dontwarn com.navercorp.nid.**

########################################
# 2. Retrofit 보호 (여기부터는 작성하신 내용 그대로입니다)
########################################
-keepattributes Signature, InnerClasses, EnclosingMethod
-keepattributes RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault

-keepclassmembers,allowshrinking,allowobfuscation interface * {
    @retrofit2.http.* <methods>;
}

-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn javax.annotation.**
-dontwarn kotlin.Unit
-dontwarn retrofit2.KotlinExtensions
-dontwarn retrofit2.KotlinExtensions$*

-if interface * { @retrofit2.http.* <methods>; }
-keep,allowobfuscation interface <1>

-if interface * { @retrofit2.http.* <methods>; }
-keep,allowobfuscation interface * extends <1>

-keep,allowoptimization,allowshrinking,allowobfuscation class kotlin.coroutines.Continuation

-if interface * { @retrofit2.http.* public *** *(...); }
-keep,allowoptimization,allowshrinking,allowobfuscation class <3>

-keep,allowoptimization,allowshrinking,allowobfuscation class retrofit2.Response

# 추가 안전장치 (OkHttp 등)
-keepattributes *Annotation*
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okio.**