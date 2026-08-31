import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProps = Properties()
val signingPropsFile = rootProject.file("../secrets/android-signing.properties")
val hasSigningProps = signingPropsFile.exists()
if (hasSigningProps) {
    signingPropsFile.inputStream().use { signingProps.load(it) }
}

val adMobAppId = providers.gradleProperty("KVIZ_ADMOB_APP_ID")
    .orElse(providers.environmentVariable("KVIZ_ADMOB_APP_ID"))
    .orElse("ca-app-pub-5116758828202889~3118136439")

android {
    namespace = "rs.in.dbase.kviz"
    // flutter_secure_storage 11+ zahteva API 37; flutter.compileSdkVersion je jos na 36
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "rs.in.dbase.kviz"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["adMobAppId"] = adMobAppId.get()
    }

    signingConfigs {
        if (hasSigningProps) {
            create("release") {
                storeFile = rootProject.file("../secrets/kviz-release.jks")
                storePassword = signingProps.getProperty("storePassword")
                keyAlias = signingProps.getProperty("keyAlias")
                keyPassword = signingProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("profile") {
            if (hasSigningProps) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
        release {
            signingConfig = if (hasSigningProps) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("com.google.android.play:integrity:1.6.0")
    implementation("com.google.android.gms:play-services-games-v2:22.0.0")
}

flutter {
    source = "../.."
}