plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.attendance_system"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.2.12479018" // ✅ Directly set the correct NDK version

    compileOptions {
        isCoreLibraryDesugaringEnabled = true // ✅ Correct syntax for Kotlin DSL
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8" // ✅ Ensure compatibility with Java target
    }

    defaultConfig {
        applicationId = "com.example.attendance_system"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2") // ✅ Correct configuration for desugaring
}

flutter {
    source = "../.."
}
