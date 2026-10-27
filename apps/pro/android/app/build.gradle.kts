plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.maisonmakas.pro"
    compileSdk = flutter.compileSdkVersion
    // CI'da Flutter'ın istediği NDK indirilemezse ci/derle.sh makinede kurulu olanı verir (maisonNdk).
    ndkVersion = (project.findProperty("maisonNdk") as String?) ?: flutter.ndkVersion

    compileOptions {
        // Bildirim eklentisi (flutter_local_notifications) yeni Java API'lerini eski Android'lerde de kullanır.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.maisonmakas.pro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Cloud Messaging en az Android 7 (API 24) ister.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Maison Makas imzaları:
    //  - Test derlemeleri (ci/derle.sh) depodaki ci/debug.keystore ile imzalanır; her yeni APK eskisinin üstüne kurulur.
    //  - Google Play paketleri (ci/play.sh) yükleme anahtarıyla imzalanır. Anahtar depoda yalnız şifreli durur
    //    (ci/play/upload.p12.gpg); play.sh onu GitHub Secrets'taki parolayla geçici bir klasöre açar ve yolunu verir.
    val maisonYukleme: String? = System.getenv("MAISON_UPLOAD_STORE_FILE")?.takeIf { it.isNotBlank() }
    signingConfigs {
        create("maisonTest") {
            storeFile = file("../../../../ci/debug.keystore")
            storeType = "jks"
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (maisonYukleme != null) {
            create("maisonYukleme") {
                storeFile = file(maisonYukleme)
                storeType = "pkcs12"
                storePassword = System.getenv("MAISON_UPLOAD_PASSWORD")
                keyAlias = "upload"
                keyPassword = System.getenv("MAISON_UPLOAD_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Küçültme (R8) Flutter eklentisince açılır; kurallar: app/proguard-rules.pro ve res/raw/keep.xml.
            signingConfig = signingConfigs.getByName(if (maisonYukleme != null) "maisonYukleme" else "maisonTest")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
