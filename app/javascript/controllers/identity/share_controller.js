// ⚡ FRONT · identity/share_controller — partage d'un lien d'invitation : WhatsApp, SMS, copie, partage natif du système
// Rôle : chaque partage est enregistré par notre serveur (sendBeacon, sur la session), sans traceur ; le lien s'ouvre quoi qu'il arrive
// ADR  : 0049, 0051, 0063 · UDR : 0050
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["native", "copied", "failed"]
  static values = { url: String, link: String, text: String }

  // Le partage natif n'existe que sur certains navigateurs : le bouton reste caché ailleurs.
  connect() {
    if (this.hasNativeTarget && typeof navigator.share === "function") this.nativeTarget.hidden = false
  }

  // WhatsApp et SMS sont de vrais liens : on compte, puis le navigateur les ouvre.
  record({ params: { channel } }) {
    this.send(channel)
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.linkValue)
    } catch {
      // Presse-papiers absent (page hors HTTPS) ou refusé par le navigateur.
      return this.toast(this.failedTarget)
    }
    this.toast(this.copiedTarget)
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

  // Même motif que classroom--join-code-copy : le toast est rendu par le serveur, cloné avec un id neuf.
  toast(template) {
    const toast = template.content.firstElementChild.cloneNode(true)
    toast.id = `toast-${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`
    document.getElementById("toasts").append(toast)
  }
}
