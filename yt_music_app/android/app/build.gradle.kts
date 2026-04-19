plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ytmusic.yt_music_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ytmusic.yt_music_app"
        minSdk = 24          // Android 7.0+ (รองรับ ~97% ของมือถือ, audio_service ทำงานดีสุด)
        targetSdk = 36       // Android 14 (compatibility กว้าง)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true  // รองรับ APK ขนาดใหญ่
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
