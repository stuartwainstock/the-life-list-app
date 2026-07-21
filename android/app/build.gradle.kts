plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.thelifelist.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.thelifelist.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Replace with a real release signingConfig before uploading
            // to Play (blocker for store submission — see README "Release
            // builds"). Debug keys keep `flutter run --release` working.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ABI splits for sideloaded APKs: prefer Flutter's CLI flag rather than
    // a gradle `splits { abi { ... } }` block —
    //   flutter build apk --release --split-per-abi
    // Play Store releases use an App Bundle instead (`flutter build
    // appbundle --release`); Play does per-device splitting server-side.
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
