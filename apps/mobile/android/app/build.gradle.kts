import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Resolve a signing value from key.properties first, then an env var (CI).
fun signingValue(propKey: String, envKey: String): String? =
    keystoreProperties.getProperty(propKey) ?: System.getenv(envKey)

android {
    // `namespace` is the internal R/BuildConfig package and must match the Kotlin
    // source package (MainActivity.kt lives in com.example.bjj_open_mat). It is
    // intentionally decoupled from `applicationId` below (the installed package id).
    namespace = "com.example.bjj_open_mat"
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
        applicationId = "com.davissylvester.bjjopenmat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Overridable at build time: -Pauth0Domain=... -PmapsApiKey=... (CI passes these from secrets).
        manifestPlaceholders["auth0Domain"] =
            (project.findProperty("auth0Domain") as String?) ?: System.getenv("AUTH0_DOMAIN") ?: "your-tenant.auth0.com"
        manifestPlaceholders["auth0Scheme"] = "https"
        manifestPlaceholders["mapsApiKey"] =
            (project.findProperty("mapsApiKey") as String?) ?: System.getenv("MAPS_API_KEY") ?: ""
    }

    signingConfigs {
        create("release") {
            val storeFilePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Use the real release keystore when configured; otherwise fall back to
            // debug signing so a fresh clone without key.properties still builds.
            signingConfig = if (signingValue("storeFile", "ANDROID_KEYSTORE_PATH") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
