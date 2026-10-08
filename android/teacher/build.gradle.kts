// App « Lnclass Teacher » des enseignants (ADR-0085) : une coque Hotwire Native qui affiche les pages du site, sur le
// socle partagé avec l'app élèves.
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Clé d'envoi hors dépôt (ADR-0084 §4.8), la même que celle de l'app élèves : variables d'environnement, ou
// local.properties sur le poste.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

fun signingValue(env: String, local: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: localProperties.getProperty(local)?.takeIf { it.isNotBlank() }

val keystorePath = signingValue("LNCLASS_KEYSTORE_PATH", "lnclass.keystore.path")

android {
    namespace = "com.lnclass.teacher"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.lnclass.teacher"
        minSdk = 28 // Android 9, plancher de Hotwire Native Android (ADR-0070 amendé)
        targetSdk = 36 // Android 16 : le Play Store relève chaque fin août l'API cible exigée
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
        // Trois marches : develop (premier test), recette (second test, avant la mise en production), production.
        create("develop") {
            dimension = "environment"
            applicationIdSuffix = ".develop"
            buildConfigField("String", "BASE_URL", "\"https://app-develop.lnclass.com\"")
            manifestPlaceholders["appHost"] = "app-develop.lnclass.com"
            resValue("string", "app_name", "Lnclass Teacher develop")
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
        create("recette") {
            dimension = "environment"
            applicationIdSuffix = ".recette"
            buildConfigField("String", "BASE_URL", "\"https://app-staging.lnclass.com\"")
            manifestPlaceholders["appHost"] = "app-staging.lnclass.com"
            resValue("string", "app_name", "Lnclass Teacher recette")
            // Sans clé d'envoi, la recette se signe avec la clé de debug du poste : un APK de test, jamais publié.
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
        create("production") {
            dimension = "environment"
            buildConfigField("String", "BASE_URL", "\"https://lnclass.com\"")
            manifestPlaceholders["appHost"] = "lnclass.com"
            resValue("string", "app_name", "Lnclass Teacher")
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

// Hotwire Native, Material et l'écran de démarrage viennent avec le socle (ADR-0085 §4.8).
dependencies {
    implementation(project(":shell"))
}
