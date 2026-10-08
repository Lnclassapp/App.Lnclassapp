package com.lnclass.student

import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.google.android.material.bottomnavigation.BottomNavigationView
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.Navigator
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.navigation.tabs.navigatorConfigurations

// Activité unique : trois onglets natifs, chacun avec sa pile de pages du site (ADR-0084 §4.4).
class MainActivity : HotwireActivity() {
    private lateinit var bottomNavigationController: HotwireBottomNavigationController
    private var pendingLink: String? = null

    private val tabs by lazy {
        listOf(
            tab("home", R.string.tab_home, R.drawable.ic_tab_home, "/?source=android", R.id.home_navigator_host),
            tab("courses", R.string.tab_courses, R.drawable.ic_tab_courses, "/courses", R.id.courses_navigator_host),
            tab("classroom", R.string.tab_classroom, R.drawable.ic_tab_classroom, "/students/classroom", R.id.classroom_navigator_host)
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

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

    // Lien /c/<code> ou /join touché alors que l'app est déjà ouverte : il s'ouvre dans l'onglet courant.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        appLink(intent)?.let { bottomNavigationController.route(it) }
    }

    private fun appLink(intent: Intent?): String? =
        intent?.takeIf { it.action == Intent.ACTION_VIEW }?.dataString?.takeIf { it.startsWith(BuildConfig.BASE_URL) }

    private fun tab(name: String, title: Int, icon: Int, path: String, hostId: Int) = HotwireBottomTab(
        title = getString(title),
        iconResId = icon,
        configuration = NavigatorConfiguration(
            name = name,
            startLocation = "${BuildConfig.BASE_URL}$path",
            navigatorHostId = hostId
        )
    )
}
