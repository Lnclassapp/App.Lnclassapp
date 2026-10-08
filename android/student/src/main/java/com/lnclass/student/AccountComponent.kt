package com.lnclass.student

import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeComponentFragmentLifecycle
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import org.json.JSONObject

// Composant de pont « account » (ADR-0084 §4.2) : la page élève envoie, à « connect », de quoi dessiner l'avatar et
// les adresses du panneau du compte et de l'aide ; la barre du haut native les affiche.
class AccountComponent(
    name: String,
    private val bridgeDelegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, bridgeDelegate), BridgeComponentFragmentLifecycle {

    override fun onReceive(message: Message) {
        if (message.event == CONNECT) show(message)
    }

    // La vue de la page est recréée au retour sur elle : on redessine avec le dernier message reçu.
    override fun onViewCreated() {
        receivedMessageFor(CONNECT)?.let(::show)
    }

    override fun onDestroyView() = Unit

    private fun show(message: Message) {
        val account = Account.parse(message.jsonData) ?: return
        (bridgeDelegate.destination as? WebFragment)?.showAccount(account)
    }

    private companion object {
        const val CONNECT = "connect"
    }
}

data class Account(val initials: String, val photoUrl: String?, val menuUrl: String, val helpUrl: String) {
    companion object {
        fun parse(json: String): Account? = runCatching {
            val data = JSONObject(json)
            Account(
                initials = data.getString("initials"),
                photoUrl = data.optStringOrNull("photoUrl"),
                menuUrl = data.optStringOrNull("menuUrl") ?: "/students/menu",
                helpUrl = data.optStringOrNull("helpUrl") ?: "/aide"
            )
        }.getOrNull()

        private fun JSONObject.optStringOrNull(key: String): String? =
            if (isNull(key)) null else optString(key).ifBlank { null }
    }
}
