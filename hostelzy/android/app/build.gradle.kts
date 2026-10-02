plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// B3: HZ_DEMO=1 builds the demo APK (sample data, DEMO banner). It installs
// next to the real app (".demo" id, its own client in google-services.json).
val demo = System.getenv("HZ_DEMO") == "1"

android {
    namespace = "app.hostelzy.hostelzy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // F20: flutter_local_notifications needs Java 8+ APIs on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.hostelzy.hostelzy"
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
        if (demo) applicationIdSuffix = ".demo"
        manifestPlaceholders["appLabel"] = if (demo) "Hostelzy Demo" else "Hostelzy"
        manifestPlaceholders["linkScheme"] = if (demo) "hostelzy-demo" else "hostelzy"
    }

    // F13: test APKs need a fixed signing key (stable SHA-1) for Google
    // sign-in. CI writes it from GitHub secrets to HZ_TEST_KEYSTORE; it is
    // never in the repo. Without it (local builds), the debug key is used.
    // NOT the Play Store upload key: that one stays separate and secret.
    val testKeystore = System.getenv("HZ_TEST_KEYSTORE")?.let { file(it) }?.takeIf { it.exists() }
    signingConfigs {
        if (testKeystore != null) {
            create("hostelzyTest") {
                storeFile = testKeystore
                storePassword = System.getenv("HZ_TEST_KEYSTORE_PASSWORD")
                keyAlias = "hostelzy-test"
                keyPassword = System.getenv("HZ_TEST_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (testKeystore != null) "hostelzyTest" else "debug")
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
