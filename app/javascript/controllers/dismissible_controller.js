// ⚡ FRONT · dismissible_controller — une bannière que l'élève masque d'une croix ; le choix reste sur cet appareil
// Rôle : cache l'élément si sa clé est dans localStorage ; « masquer » la pose et le cache ; jamais de requête ni de compte (échec du stockage : la bannière se masque pour la page)
// UDR  : XXXX écrans minimalistes style Wave §3 (accueil, bannière d'invitation)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    this.element.hidden = this.stored()
  }

  hide() {
    try { window.localStorage.setItem(this.storageKey, "1") } catch { /* stockage refusé : masquée pour cette page seulement */ }
    this.element.hidden = true
  }

  stored() {
    try { return window.localStorage.getItem(this.storageKey) === "1" } catch { return false }
  }

  get storageKey() {
    return `lnclass.dismissed.${this.keyValue}`
  }
}
