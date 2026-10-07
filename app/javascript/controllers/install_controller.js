// ⚡ FRONT · install_controller — bandeau d'installation : « Installer » sur Android, mode d'emploi sur Safari iPhone
// Rôle : montre le bandeau caché par le serveur ; « Plus tard » le tait 3 jours sur ce téléphone (localStorage, jamais le serveur)
// UDR  : 0078 · ADR : 0082, 0049
import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "lnclass.install.later_until"
const LATER_DAYS = 3
const DAY = 24 * 60 * 60 * 1000

// Le navigateur n'annonce l'installation qu'une fois par document : gardée ici, elle sert encore après une visite Turbo.
let deferred = null

export default class extends Controller {
  static targets = ["android", "ios"]

  connect() {
    this.offer = this.offer.bind(this)
    this.hide = this.hide.bind(this)
    this.reveal = this.reveal.bind(this)
    if (window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true) return
    if (this.laterUntil() > Date.now()) return

    const agent = navigator.userAgent
    if (/iPhone|iPad/.test(agent) && !/CriOS|FxiOS|EdgiOS/.test(agent)) {
      this.show(this.iosTarget)
    } else {
      if (deferred) this.show(this.androidTarget)
      window.addEventListener("beforeinstallprompt", this.offer)
    }
    window.addEventListener("appinstalled", this.hide)
    // Un rafraîchissement fusionné (morph) remet le `hidden` du serveur sans reconnecter le contrôleur.
    document.addEventListener("turbo:morph", this.reveal)
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.offer)
    window.removeEventListener("appinstalled", this.hide)
    document.removeEventListener("turbo:morph", this.reveal)
  }

  offer(event) {
    event.preventDefault()
    deferred = event
    this.show(this.androidTarget)
  }

  async prompt() {
    const event = deferred
    deferred = null
    if (!event) return this.later()
    try {
      await event.prompt()
      const { outcome } = await event.userChoice
      outcome === "accepted" ? this.hide() : this.later()
    } catch {
      this.later()
    }
  }

  later() {
    try {
      localStorage.setItem(STORAGE_KEY, String(Date.now() + LATER_DAYS * DAY))
    } catch {}
    this.hide()
    document.getElementById("main")?.focus()
  }

  laterUntil() {
    try {
      return Number(localStorage.getItem(STORAGE_KEY)) || 0
    } catch {
      return 0
    }
  }

  show(target) {
    this.shown = target
    this.reveal()
  }

  reveal() {
    if (!this.shown) return
    this.shown.hidden = false
    this.element.hidden = false
  }

  hide() {
    this.shown = null
    this.element.hidden = true
  }
}
