// ⚡ FRONT · offline-status — affiche le bandeau « Hors ligne » (page gardée) et la date où elle a été gardée
// Rôle : visible hors ligne, ou si le programme d'arrière-plan a servi la page du cache (meta lnclass-offline-served) ; caché au retour du réseau
// UDR  : hors-connexion §3.1 · ADR : hors-connexion §4.3
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]
  static values = { offlineText: String, savedOnTemplate: String, dateFormat: { type: String, default: "%{day}/%{month} à %{hour}:%{minute}" } }

  connect() {
    this.refresh = this.refresh.bind(this)
    window.addEventListener("online", this.refresh)
    window.addEventListener("offline", this.refresh)
    this.refresh()
  }

  disconnect() {
    window.removeEventListener("online", this.refresh)
    window.removeEventListener("offline", this.refresh)
  }

  refresh() {
    const savedAt = this.savedAt()
    const offline = navigator.onLine === false
    this.element.hidden = !(offline || savedAt)
    if (this.element.hidden) return

    const saved = savedAt ? ` ${this.savedOnTemplateValue.replace("%{date}", this.format(savedAt))}` : ""
    this.textTarget.textContent = `${this.offlineTextValue}${saved}`
  }

  // L'heure à laquelle le programme d'arrière-plan a gardé la page, ou null (page venue du réseau, meta absente ou illisible).
  savedAt() {
    const value = document.querySelector('meta[name="lnclass-offline-served"]')?.content
    const date = value ? new Date(value) : null
    return date && !Number.isNaN(date.getTime()) ? date : null
  }

  format(date) {
    const two = (number) => String(number).padStart(2, "0")
    return this.dateFormatValue.replace("%{day}", two(date.getDate())).replace("%{month}", two(date.getMonth() + 1))
      .replace("%{hour}", two(date.getHours())).replace("%{minute}", two(date.getMinutes()))
  }
}
