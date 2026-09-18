import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}
val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
// CI/local secure stores may supply credentials without a plaintext properties file.
mapOf(
    "storeFile" to "TEACHER_ANDROID_STORE_FILE",
    "storePassword" to "TEACHER_ANDROID_STORE_PASSWORD",
    "keyAlias" to "TEACHER_ANDROID_KEY_ALIAS",
    "keyPassword" to "TEACHER_ANDROID_KEY_PASSWORD",
).forEach { (property, environment) ->
    if (keystoreProperties.getProperty(property).isNullOrBlank()) {
        System.getenv(environment)?.let { keystoreProperties.setProperty(property, it) }
    }
}
val hasReleaseSigning = releaseSigningKeys.all {
    !keystoreProperties.getProperty(it).isNullOrBlank()
}
val isReleaseTask = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
if (isReleaseTask && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Copy key.properties.example to " +
            "android/key.properties and provide the private keystore values.",
    )
}

android {
    namespace = "com.school.teacher.teacher_mobile"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.school.teacher.teacher_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
