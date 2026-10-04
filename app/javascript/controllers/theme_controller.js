// ⚡ FRONT · theme_controller — interrupteur clair / sombre, retenu sur cet appareil (cookie `theme`, un an)
// Rôle : pose data-theme sur <html> et la meta color-scheme, tient aria-checked à jour ; l'interrupteur est caché sans JS
// UDR  : 0065 (amendement du 2026-10-03) · ADR : 0049 (aucun script en ligne)
import { Controller } from "@hotwired/stimulus"

const ONE_YEAR = 60 * 60 * 24 * 365

export default class extends Controller {
  static targets = ["switch"]

  connect() {
    this.media = window.matchMedia("(prefers-color-scheme: dark)")
    this.sync = this.sync.bind(this)
    this.media.addEventListener("change", this.sync)
    this.sync()
    this.element.hidden = false
  }

  disconnect() {
    this.media.removeEventListener("change", this.sync)
  }

  // Le choix vaut pour toutes les pages de cet appareil : le serveur le relit dans le cookie au prochain chargement.
  toggle() {
    const theme = this.dark ? "light" : "dark"
    document.documentElement.dataset.theme = theme
    document.querySelector('meta[name="color-scheme"]')?.setAttribute("content", theme)
    const secure = window.location.protocol === "https:" ? "; Secure" : ""
    document.cookie = `theme=${theme}; path=/; max-age=${ONE_YEAR}; SameSite=Lax${secure}`
    window.dispatchEvent(new CustomEvent("theme:changed"))
  }

  // Les deux interrupteurs d'une page (en-tête, profil) disent la même chose ; sans choix, ils suivent le téléphone.
  sync() {
    this.switchTargets.forEach((element) => element.setAttribute("aria-checked", String(this.dark)))
  }

  get dark() {
    const chosen = document.documentElement.dataset.theme
    return chosen ? chosen === "dark" : this.media.matches
  }
}
