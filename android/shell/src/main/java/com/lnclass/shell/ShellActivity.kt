package com.lnclass.shell

import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.annotation.DrawableRes
import androidx.annotation.IdRes
import androidx.annotation.LayoutRes
import androidx.annotation.StringRes
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.navigation.tabs.navigatorConfigurations

// Activité unique d'une coque : des onglets natifs, chacun avec sa pile de pages du site (ADR-0084 §4.4). L'app
// fournit sa mise en page (une NavigatorHost par onglet, au-dessus de R.id.bottom_navigation), son site et ses onglets.
abstract class ShellActivity(@LayoutRes private val layout: Int) : HotwireActivity() {
    protected abstract val baseUrl: String
    protected abstract val tabs: List<HotwireBottomTab>

    private lateinit var bottomNavigationController: HotwireBottomNavigationController
    private var pendingLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(layout)

        // La barre d'onglets se cache d'elle-même en contexte modal (séance d'exercice, panneau du compte, aide).
        bottomNavigationController = HotwireBottomNavigationController(
            activity = this,
            view = findViewById<BottomNavigationView>(R.id.bottom_navigation),
            lazyLoadTabs = true
        )
        bottomNavigationController.load(tabs)

        if (savedInstanceState == null) pendingLink = appLink(intent)
    }

    override fun navigatorConfigurations(): List<NavigatorConfiguration> = tabs.navigatorConfigurations

    override fun onNavigatorReady(navigator: Navigator) {
        super.onNavigatorReady(navigator)
        if (navigator.configuration == tabs.first().configuration) {
            pendingLink?.let { navigator.route(it) }
            pendingLink = null
        }
    }

    // Lien profond touché alors que l'app est déjà ouverte : il s'ouvre dans l'onglet courant.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        appLink(intent)?.let { bottomNavigationController.route(it) }
    }

    private fun appLink(intent: Intent?): String? =
        intent?.takeIf { it.action == Intent.ACTION_VIEW }?.dataString?.takeIf { it.startsWith(baseUrl) }

    protected fun tab(name: String, @StringRes title: Int, @DrawableRes icon: Int, path: String, @IdRes hostId: Int) =
        HotwireBottomTab(
            title = getString(title),
            iconResId = icon,
            configuration = NavigatorConfiguration(
                name = name,
                startLocation = "$baseUrl$path",
                navigatorHostId = hostId
            )
        )
}
