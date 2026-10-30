import java.util.Properties
import java.io.FileInputStream
import java.io.FileNotFoundException

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
try {
    val keystorePropertiesFile = rootProject.file("key.properties")
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} catch (e: FileNotFoundException) {
    println("Warning: key.properties file not found. Ensure the file is present before building the release version.")
}

// The application ID is stable for the kenzo build, but downstream ports can
// override it without editing this file:
//   flutter build apk --release --flavor production \
//     -PdapApplicationId=org.example.player
val dapApplicationId =
    (project.findProperty("dapApplicationId") as String?) ?: "com.sundara.classipod"
val hasReleaseSigning =
    keystoreProperties.getProperty("storeFile") != null &&
        rootProject.file(keystoreProperties.getProperty("storeFile")).exists()

android {
    namespace = "com.adeeteya.classipod"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = dapApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk.abiFilters.addAll(arrayOf("armeabi-v7a", "arm64-v8a", "x86_64"))
    }

    buildFeatures {
        resValues = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as? String
            keyPassword = keystoreProperties["keyPassword"] as? String
            storePassword = keystoreProperties["storePassword"] as? String
            val storeFilePath = keystoreProperties["storeFile"] as? String
            if (storeFilePath != null) {
                storeFile = rootProject.file(storeFilePath)
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            // A release build without key.properties is debug-signed so that
            // contributors can still test it. Public releases must be built
            // with a real keystore; scripts/build-app.sh enforces that.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    flavorDimensions += "default"
    productFlavors {
        create("production") {
            dimension = "default"
            resValue("string", "app_name", "Classipod")
            applicationIdSuffix = ""
        }
        create("dev") {
            dimension = "default"
            resValue("string", "app_name", "Classipod Dev")
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
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
