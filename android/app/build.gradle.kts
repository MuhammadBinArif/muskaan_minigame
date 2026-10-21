plugins {
    id("com.android.application")
    // ✅ APPLY the Kotlin Android plugin – required because builtInKotlin=false
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.muskaan_minigame"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.muskaan_minigame"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
        }
        getByName("release") {
            // Set with -PadmobAppId=ca-app-pub-...~... for a production build.
            val productionId = providers.gradleProperty("admobAppId").orNull
            if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
                require(!productionId.isNullOrBlank() && productionId != "ca-app-pub-3940256099942544~3347511713") {
                    "Release requires a real AdMob app ID: -PadmobAppId=ca-app-pub-...~..."
                }
            }
            manifestPlaceholders["admobAppId"] = productionId ?: "MISSING_PRODUCTION_ADMOB_APP_ID"
        }
    }

    buildTypes.getByName("release").signingConfig = signingConfigs.getByName("debug")
}

// ✅ CORRECT: kotlin block at TOP LEVEL, outside android {}
kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}
