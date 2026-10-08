// Coque Android de Lnclass (ADR-0070, ADR-0084 §4.8) : un module d'app par public, `student` aujourd'hui.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "lnclass-android"
include(":student")
