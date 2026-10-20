plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.maisonmakas.musteri"
    compileSdk = flutter.compileSdkVersion
    // CI'da Flutter'ın istediği NDK indirilemezse ci/derle.sh makinede kurulu olanı verir (maisonNdk).
    ndkVersion = (project.findProperty("maisonNdk") as String?) ?: flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.maisonmakas.musteri"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Maison Makas: test derlemeleri depodaki ci/debug.keystore ile imzalanır.
    // Her derleme aynı anahtarı kullandığı için yeni sürüm eskisinin üstüne kurulur.
    // Google Play için ayrı bir yükleme anahtarı kullanılacak (rehber 13. adım).
    signingConfigs {
        create("maisonTest") {
            storeFile = file("../../../../ci/debug.keystore")
            storeType = "jks"
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("maisonTest")
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
