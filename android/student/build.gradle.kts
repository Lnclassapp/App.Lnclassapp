// App « Lnclass » des élèves (ADR-0084) : une coque Hotwire Native qui affiche les pages du site.
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Clé d'envoi hors dépôt (ADR-0084 §4.8) : variables d'environnement, ou local.properties sur le poste.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(env: String, local: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: localProperties.getProperty(local)?.takeIf { it.isNotBlank() }

val keystorePath = signingValue("LNCLASS_KEYSTORE_PATH", "lnclass.keystore.path")

android {
    namespace = "com.lnclass.student"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.lnclass.student"
        minSdk = 28 // Android 9, plancher de Hotwire Native Android (ADR-0070 amendé)
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        if (keystorePath != null) {
            create("upload") {
                storeFile = file(keystorePath)
                storePassword = signingValue("LNCLASS_KEYSTORE_PASSWORD", "lnclass.keystore.password")
                keyAlias = signingValue("LNCLASS_KEY_ALIAS", "lnclass.key.alias")
                keyPassword = signingValue("LNCLASS_KEY_PASSWORD", "lnclass.key.password")
            }
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("recette") {
            dimension = "environment"
            applicationIdSuffix = ".recette"
            buildConfigField("String", "BASE_URL", "\"https://app-staging.lnclass.com\"")
            manifestPlaceholders["appHost"] = "app-staging.lnclass.com"
            resValue("string", "app_name", "Lnclass recette")
            // Sans clé d'envoi, la recette se signe avec la clé de debug du poste : un APK de test, jamais publié.
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
        create("production") {
            dimension = "environment"
            buildConfigField("String", "BASE_URL", "\"https://lnclass.com\"")
            manifestPlaceholders["appHost"] = "lnclass.com"
            resValue("string", "app_name", "Lnclass")
            signingConfig = signingConfigs.findByName("upload")
        }
    }

    buildTypes {
        release {
            // Un APK léger pour les téléphones d'entrée de gamme (cible : 10 Mo au plus).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("dev.hotwire:core:1.3.1")
    implementation("dev.hotwire:navigation-fragments:1.3.1")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("com.google.android.material:material:1.12.0")
}
