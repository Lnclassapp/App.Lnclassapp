// ⚡ FRONT · identity/share_controller — partage d'un lien d'invitation : WhatsApp, SMS, partage natif du système, comptage de la copie
// Rôle : chaque partage est enregistré par notre serveur (sendBeacon, sur la session), sans traceur ; la copie elle-même est au contrôleur clipboard
// ADR  : 0049, 0051, 0063 · UDR : 0050, 0054 (§3.5 : « clipboard:copied->identity--share#recordCopy »)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native"]
  static values = { url: String, link: String, text: String }

  // Le partage natif n'existe que sur certains navigateurs : le bouton reste caché ailleurs.
  connect() {
    if (this.hasNativeTarget && typeof navigator.share === "function") this.nativeTarget.hidden = false
  }

  // WhatsApp et SMS sont de vrais liens : on compte, puis le navigateur les ouvre.
  record({ params: { channel } }) {
    this.send(channel)
  }

  // Le contrôleur clipboard a copié le lien (événement clipboard:copied) : seule une copie réussie est comptée.
  recordCopy() {
    this.send("copy")
  }

  async native() {
    try {
      await navigator.share({ text: this.textValue, url: this.linkValue })
    } catch {
      return // partage annulé : rien n'est compté
    }
    this.send("native")
  }

  send(channel) {
    const body = new FormData()
    body.append("channel", channel)
    const token = document.querySelector("meta[name=csrf-token]")?.content
    if (token) body.append("authenticity_token", token)
    navigator.sendBeacon(this.urlValue, body)
  }
}
