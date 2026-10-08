// Socle partagé des coques Lnclass (ADR-0085 §4.8) : fragment web, barre du haut, avatar, pont « account »,
// onglets et configuration Hotwire. Chaque app (student, teacher) n'y ajoute que ce qui lui est propre.
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.lnclass.shell"
    compileSdk = 36

    defaultConfig {
        minSdk = 28 // Android 9, plancher de Hotwire Native Android (ADR-0070 amendé)
        consumerProguardFiles("consumer-rules.pro")
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

// Exposées aux apps : leurs activités, leurs thèmes et leurs mises en page s'appuient dessus.
dependencies {
    api("dev.hotwire:core:1.3.1")
    api("dev.hotwire:navigation-fragments:1.3.1")
    api("androidx.core:core-splashscreen:1.0.1")
    api("com.google.android.material:material:1.12.0")
}
