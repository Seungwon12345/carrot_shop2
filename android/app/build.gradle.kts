import java.util.Properties
import java.io.FileInputStream

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.carrot_shop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.carrot_shop"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 👇 [여기입니다!] 아까 만드신 키 정보를 여기에 적는 겁니다.
    signingConfigs {
        create("release") {
            storeFile = file("my_key.jks")  // 파일 이름
            storePassword = "123456"        // 아까 설정한 비번
            keyAlias = "my-alias"           // 아까 설정한 별칭
            keyPassword = "123456"          // 아까 설정한 비번
        }
    }

    buildTypes {
        release {
            // 코드 난독화 및 리소스 축소 활성화
            isMinifyEnabled = true
            isShrinkResources = true

            // 네이버 로그인 보호 규칙 파일 연결
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // ⭐️ 위에서 만든 'release' 서명 정보를 사용하겠다고 설정
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}