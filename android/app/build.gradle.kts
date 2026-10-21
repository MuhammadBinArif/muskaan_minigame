import java.util.Base64

plugins {
    id("com.android.application")
    // ✅ APPLY the Kotlin Android plugin – required because builtInKotlin=false
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val sampleAppId = "ca-app-pub-3940256099942544~3347511713"
val productionId = providers.gradleProperty("admobAppId").orNull

if (releaseRequested) {
    require(productionId?.matches(Regex("ca-app-pub-\\d{16}~\\d{10}")) == true && productionId != sampleAppId) {
        "Release requires a real AdMob app ID: -PadmobAppId=ca-app-pub-...~..."
    }
    val defines = providers.gradleProperty("dart-defines").orNull.orEmpty()
        .split(',').filter { it.isNotBlank() }.mapNotNull {
            runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull()
        }.mapNotNull { it.split('=', limit = 2).takeIf { parts -> parts.size == 2 } }
        .associate { it[0] to it[1] }
    for (key in listOf("ADMOB_INTERSTITIAL_ID", "ADMOB_REWARDED_ID")) {
        val id = defines[key]
        require(id?.matches(Regex("ca-app-pub-\\d{16}/\\d{10}")) == true && !id.startsWith("ca-app-pub-3940256099942544/")) {
            "Release requires a real $key supplied with --dart-define=$key=ca-app-pub-.../..."
        }
    }
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
            manifestPlaceholders["admobAppId"] = productionId ?: "MISSING_PRODUCTION_ADMOB_APP_ID"
        }
    }

    if (releaseRequested) {
        val storePath = providers.environmentVariable("MUSKAAN_STORE_FILE").orNull
        val storePasswordValue = providers.environmentVariable("MUSKAAN_STORE_PASSWORD").orNull
        val keyAliasValue = providers.environmentVariable("MUSKAAN_KEY_ALIAS").orNull
        val keyPasswordValue = providers.environmentVariable("MUSKAAN_KEY_PASSWORD").orNull
        require(!storePath.isNullOrBlank() && !storePasswordValue.isNullOrBlank() &&
                !keyAliasValue.isNullOrBlank() && !keyPasswordValue.isNullOrBlank()) {
            "Release signing requires MUSKAAN_STORE_FILE, MUSKAAN_STORE_PASSWORD, MUSKAAN_KEY_ALIAS, and MUSKAAN_KEY_PASSWORD environment variables."
        }
        val signingFile = file(storePath)
        require(signingFile.isFile) { "Release signing file does not exist at MUSKAAN_STORE_FILE." }
        signingConfigs.create("production") {
            storeFile = signingFile
            storePassword = storePasswordValue
            keyAlias = keyAliasValue
            keyPassword = keyPasswordValue
        }
        buildTypes.getByName("release").signingConfig = signingConfigs.getByName("production")
    }
}

// ✅ CORRECT: kotlin block at TOP LEVEL, outside android {}
kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}
