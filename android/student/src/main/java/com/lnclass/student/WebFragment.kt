package com.lnclass.student

import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import androidx.core.view.isVisible
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.util.concurrent.Executors

// Page du site sous la barre du haut native (UDR-0080 §3.3). Même adresse de destination que le fragment web de
// Hotwire, pour que la configuration des chemins (« hotwire://fragment/web ») s'y applique.
@HotwireDestinationDeepLink(uri = "hotwire://fragment/web")
class WebFragment : HotwireWebFragment() {
    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View? =
        inflater.inflate(R.layout.fragment_web, container, false)

    // En modale (séance, panneau du compte, aide), seule la croix native reste. Ailleurs, l'aide à droite ; et,
    // sur la page racine d'un onglet, l'avatar à gauche, là où une page intérieure montre la flèche retour.
    fun showAccount(account: Account) {
        if (isModal) return
        val toolbar = toolbarForNavigation() ?: return

        if (navigator.isAtStartDestination()) {
            val avatar = AvatarDrawable(requireContext(), account.initials)
            toolbar.navigationIcon = avatar
            toolbar.navigationContentDescription = getString(R.string.account_open)
            toolbar.setNavigationOnClickListener { navigator.route(absolute(account.menuUrl)) }
            account.photoUrl?.let { loadPhoto(absolute(it), avatar, toolbar) }
        }

        view?.findViewById<View>(R.id.help_button)?.apply {
            isVisible = true
            setOnClickListener { navigator.route(absolute(account.helpUrl)) }
        }
    }

    private fun absolute(url: String): String = URI(location).resolve(url).toString()

    // Photo de profil : un seul petit fichier, chargé hors du fil principal avec le cookie de la session ; en cas
    // d'échec, les initiales restent.
    private fun loadPhoto(url: String, avatar: AvatarDrawable, target: View) {
        photoLoader.execute {
            val bitmap = runCatching {
                val connection = URL(url).openConnection() as HttpURLConnection
                CookieManager.getInstance().getCookie(url)?.let { connection.setRequestProperty("Cookie", it) }
                connection.connectTimeout = TIMEOUT_MS
                connection.readTimeout = TIMEOUT_MS
                try {
                    connection.inputStream.use(BitmapFactory::decodeStream)
                } finally {
                    connection.disconnect()
                }
            }.getOrNull()
            bitmap?.let { target.post { avatar.setPhoto(it) } }
        }
    }

    private companion object {
        const val TIMEOUT_MS = 10_000
        val photoLoader = Executors.newSingleThreadExecutor()
    }
}
