plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_kependudukan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "25.1.8937393" 

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_kependudukan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion ?: 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode()
        versionName = flutter.versionName()
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // Add proguard configuration for R8
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }

    // Add configuration to avoid R8 full mode issues
    packagingOptions {
        resources.excludes.add("META-INF/DEPENDENCIES")
        resources.excludes.add("META-INF/LICENSE")
        resources.excludes.add("META-INF/LICENSE.txt")
        resources.excludes.add("META-INF/license.txt")
        resources.excludes.add("META-INF/NOTICE")
        resources.excludes.add("META-INF/NOTICE.txt")
        resources.excludes.add("META-INF/notice.txt")
        resources.excludes.add("META-INF/*.kotlin_module")
    }
}

dependencies {
    // Add these dependencies to fix the R8 errors
    implementation("com.google.errorprone:error_prone_annotations:2.20.0")
    implementation("com.google.code.findbugs:jsr305:3.0.2")

    // Play Core library - commented out if not needed
    // implementation("com.google.android.play:core:1.10.3") // Use stable version
    
    // Ganti apache httpclient dengan okhttp3
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Joda Time library
    implementation("joda-time:joda-time:2.12.5")
}

flutter {
    source = "../.."
}
