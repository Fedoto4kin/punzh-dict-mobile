import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "host.punzh.punzh_dict"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "host.punzh.punzh_dict"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            check(keystorePropertiesFile.exists()) {
                "Missing android/key.properties — copy key.properties.example and point storeFile at the upload keystore. Dev/USB: use branch `dev` (debug signing)."
            }
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: error("key.properties: keyAlias required")
            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: error("key.properties: keyPassword required")
            storePassword = keystoreProperties.getProperty("storePassword")
                ?: error("key.properties: storePassword required")
            val storePath = keystoreProperties.getProperty("storeFile")
                ?: error("key.properties: storeFile required")
            storeFile = rootProject.file(storePath)
            check(storeFile!!.isFile) {
                "keystore not found: ${storeFile!!.absolutePath}"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // AGP lintVital crashes on JDK 18 (CommentDetector / List.removeLast) while
    // scanning plugin sources (e.g. url_launcher). Skip for release APK builds.
    lint {
        checkReleaseBuilds = false
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

// Versioned artifact base name → punzh-dict-{versionName}-{versionCode}-{buildType}.apk
// (see AGENTS.md). Flutter copies the same basename into flutter-apk/.
base {
    archivesName.set("punzh-dict-${flutter.versionName}-${flutter.versionCode}")
}
