package com.lnclass.shell

import android.content.Context
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.defaultFragmentDestination
import dev.hotwire.navigation.config.registerBridgeComponents
import dev.hotwire.navigation.config.registerFragmentDestinations

// Configuration Hotwire Native commune aux deux apps, une fois au lancement (ADR-0084 §4.1 et §4.3, ADR-0086 §4.8).
// Chaque app passe ce qui lui est propre : son jeton User-Agent, l'adresse de son site, son panneau du compte.
object Shell {
    internal var accountMenuPath = "/students/menu"
        private set

    fun configure(context: Context, userAgentPrefix: String, baseUrl: String, debug: Boolean, accountMenuPath: String) {
        this.accountMenuPath = accountMenuPath

        // Jeton lu par le site (ApplicationController#lnclass_app) ; la bibliothèque y ajoute « Hotwire Native Android ».
        Hotwire.config.applicationUserAgentPrefix = userAgentPrefix
        Hotwire.config.webViewDebuggingEnabled = debug

        // Copie embarquée pour démarrer hors ligne, puis la version servie par le site, qui fait foi.
        Hotwire.loadPathConfiguration(
            context = context,
            location = PathConfiguration.Location(
                assetFilePath = "json/path-configuration.json",
                remoteFileUrl = "$baseUrl/android/v1/path-configuration.json"
            )
        )

        Hotwire.defaultFragmentDestination = WebFragment::class
        Hotwire.registerFragmentDestinations(WebFragment::class)
        Hotwire.registerBridgeComponents(BridgeComponentFactory("account", ::AccountComponent))
    }
}
