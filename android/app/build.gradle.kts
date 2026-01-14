plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_firebase_mock_skel"
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
        applicationId = "com.example.flutter_firebase_mock_skel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
        }
        create("prod") {
            dimension = "environment"
        }
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

// Copy the appropriate google-services.json based on build variant
tasks.register("selectGoogleServices") {
    doFirst {
        val buildVariant = "${android.flavorDimensions.first()}${buildType.name.capitalize()}"
        val sourceFile = file("google-services-${android.productFlavors.first().name}.json")
        val targetFile = file("google-services.json")
        
        if (sourceFile.exists()) {
            sourceFile.copyTo(targetFile, overwrite = true)
            println("Copied google-services.json for $buildVariant")
        }
    }
}

tasks.whenTaskAdded { task ->
    if ((task.name.startsWith("process") && task.name.endsWith("GoogleServices"))) {
        task.dependsOn("selectGoogleServices")
    }
}
