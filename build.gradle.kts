plugins {
    alias(libs.plugins.android.application)
}

fun quotedForBuildConfig(value: String): String =
    "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""

fun detectActiveIpv4Address(): String? {
    return try {
        val osName = System.getProperty("os.name").lowercase()
        if (osName.contains("windows")) {
            val process = ProcessBuilder("cmd", "/c", "route print -4")
                .redirectErrorStream(true)
                .start()
            val output = process.inputStream.bufferedReader().use { it.readText() }
            val match = Regex(
                """^\s*0\.0\.0\.0\s+0\.0\.0\.0\s+\S+\s+(\d{1,3}(?:\.\d{1,3}){3})\s+\d+\s*$""",
                RegexOption.MULTILINE
            ).find(output)
            match?.groupValues?.getOrNull(1)
        } else {
            val process = ProcessBuilder("sh", "-c", "ip route | grep '^default' | awk '{print $9}'")
                .redirectErrorStream(true)
                .start()
            process.inputStream.bufferedReader().use { it.readText().trim() }.ifBlank { null }
        }
    } catch (_: Exception) {
        null
    }
}

fun detectLocalBackendBaseUrl(): String? =
    detectActiveIpv4Address()?.let { "http://$it/vegetable_api/" }

fun detectLocalMlPredictUrl(): String? =
    detectActiveIpv4Address()?.let { "http://$it:5000/predict" }

val stableBackendBaseUrl = (project.findProperty("GRUNO_BACKEND_BASE_URL") as String?)
    ?: detectLocalBackendBaseUrl()
    ?: "http://127.0.0.1/vegetable_api/"
val stableMlPredictUrl = (project.findProperty("GRUNO_ML_PREDICT_URL") as String?)
    ?: detectLocalMlPredictUrl()
    ?: "http://127.0.0.1:5000/predict"

android {
    namespace = "com.example.gruno"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.example.gruno"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField(
            "String",
            "STABLE_BACKEND_BASE_URL",
            quotedForBuildConfig(stableBackendBaseUrl)
        )
        buildConfigField(
            "String",
            "STABLE_ML_PREDICT_URL",
            quotedForBuildConfig(stableMlPredictUrl)
        )
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    buildFeatures {
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    implementation(libs.appcompat)
    implementation(libs.material)
    implementation(libs.activity)
    implementation(libs.constraintlayout)
    implementation(libs.recyclerview)
    implementation(libs.retrofit)
    implementation(libs.retrofit.converter.gson)
    implementation(libs.okhttp)
    implementation(libs.glide)
    testImplementation(libs.junit)
    androidTestImplementation(libs.ext.junit)
    androidTestImplementation(libs.espresso.core)
}
