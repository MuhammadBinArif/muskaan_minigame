import java.util.Base64

plugins {
    id("com.android.application")
    // ✅ APPLY the Kotlin Android plugin – required because builtInKotlin=false
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val productionId = providers.gradleProperty("admobAppId").orNull
val storePath = providers.environmentVariable("MUSKAAN_STORE_FILE").orNull
val storePasswordValue = providers.environmentVariable("MUSKAAN_STORE_PASSWORD").orNull
val keyAliasValue = providers.environmentVariable("MUSKAAN_KEY_ALIAS").orNull
val keyPasswordValue = providers.environmentVariable("MUSKAAN_KEY_PASSWORD").orNull
val hasSigningConfiguration = listOf(storePath, storePasswordValue, keyAliasValue, keyPasswordValue)
    .all { !it.isNullOrBlank() }

fun validateReleaseConfiguration() {
    require(productionId?.matches(Regex("ca-app-pub-\\d{16}~\\d{10}")) == true && !productionId.startsWith("ca-app-pub-3940256099942544~")) {
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
    require(hasSigningConfiguration) {
        "Release signing requires MUSKAAN_STORE_FILE, MUSKAAN_STORE_PASSWORD, MUSKAAN_KEY_ALIAS, and MUSKAAN_KEY_PASSWORD environment variables."
    }
    require(file(storePath!!).isFile) { "Release signing file does not exist at MUSKAAN_STORE_FILE." }
    require(providers.gradleProperty("dart-obfuscation").orNull == "true" &&
            !providers.gradleProperty("split-debug-info").orNull.isNullOrBlank()) {
        "Release requires --obfuscate --split-debug-info=<private-symbol-directory>."
    }
}

// Inspect the resolved task graph so aggregate tasks (build/assemble) and
// abbreviated task names cannot bypass release validation.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("release", ignoreCase = true) }) {
        validateReleaseConfiguration()
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
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            // Set with -PadmobAppId=ca-app-pub-...~... for a production build.
            manifestPlaceholders["admobAppId"] = productionId ?: "MISSING_PRODUCTION_ADMOB_APP_ID"

            // R8 shrinking, optimization, and obfuscation
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    if (hasSigningConfiguration) {
        signingConfigs.create("production") {
            storeFile = file(storePath!!)
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
