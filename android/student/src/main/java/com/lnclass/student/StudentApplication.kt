package com.lnclass.student

import android.app.Application
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations

// Configuration Hotwire Native, une fois au lancement (ADR-0084 §4.1 et §4.3).
class StudentApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // Jeton lu par le site (ApplicationController#lnclass_app) ; la bibliothèque y ajoute « Hotwire Native Android ».
        Hotwire.config.applicationUserAgentPrefix = "LnclassStudentAndroid/${BuildConfig.VERSION_NAME};"
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG

        // Copie embarquée pour démarrer hors ligne, puis la version servie par le site, qui fait foi.
        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json",
                remoteFileUrl = "${BuildConfig.BASE_URL}/android/v1/path-configuration.json"
            )
        )

        Hotwire.defaultFragmentDestination = WebFragment::class
        Hotwire.registerFragmentDestinations(WebFragment::class)
        Hotwire.registerBridgeComponents(BridgeComponentFactory("account", ::AccountComponent))
    }
}
