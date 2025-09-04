plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Google Services plugin for Firebase
}

android {
    namespace = "com.example.frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.frontend"  // Ensure this matches Firebase registration
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


    aaptOptions {
    noCompress("tflite")
    noCompress("lite")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import Firebase BoM (Bill of Materials)
    implementation(platform("com.google.firebase:firebase-bom:34.1.0"))

    // Firebase Analytics example
    implementation("com.google.firebase:firebase-analytics")

    // Firebase Auth
    implementation("com.google.firebase:firebase-auth")

    // Firebase Firestore
    implementation("com.google.firebase:firebase-firestore")

    // Firebase Storage (optional)
    implementation("com.google.firebase:firebase-storage")

    implementation("com.google.android.gms:play-services-mlkit-barcode-scanning:18.3.1")

}

// Apply the Google services plugin at the bottom
apply(plugin = "com.google.gms.google-services")
