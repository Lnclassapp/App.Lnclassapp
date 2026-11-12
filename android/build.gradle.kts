// Versions des greffons, partagées par les modules d'app et le socle. Depuis AGP 9, Kotlin est intégré à AGP
// (« built-in Kotlin ») : plus de greffon org.jetbrains.kotlin.android ; la version du compilateur se fixe ici.
buildscript {
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.21")
    }
}

plugins {
    id("com.android.application") version "9.5.1" apply false
    id("com.android.library") version "9.5.1" apply false
}
