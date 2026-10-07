// ⚡ FRONT · install_controller — pop-up d'installation : « Installer » sur Android, mode d'emploi sur Safari iPhone
// Rôle : ouvre la feuille (contrôleur modal) sur l'accueil, téléphone seulement ; fermée sans installer, elle se tait 3 jours sur ce téléphone (localStorage, jamais le serveur)
// UDR  : 0078 (amendement du 2026-10-07) · ADR : 0082, 0049
import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "lnclass.install.later_until"
const LATER_DAYS = 3
const DAY = 24 * 60 * 60 * 1000
const COMPUTER = "(min-width: 64rem)"

// Le navigateur n'annonce l'installation qu'une fois par document : gardée ici, elle sert encore après une visite Turbo.
let deferred = null

export default class extends Controller {
  static targets = ["android", "ios"]

  connect() {
    this.offer = this.offer.bind(this)
    this.installed = this.installed.bind(this)
    if (window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true) return
    if (window.matchMedia(COMPUTER).matches || this.laterUntil() > Date.now()) return

    const agent = navigator.userAgent
    if (/iPhone|iPad/.test(agent) && !/CriOS|FxiOS|EdgiOS/.test(agent)) {
      this.show(this.iosTarget)
    } else {
      if (deferred) this.show(this.androidTarget)
      window.addEventListener("beforeinstallprompt", this.offer)
    }
    window.addEventListener("appinstalled", this.installed)
  }

  disconnect() {
    window.removeEventListener("beforeinstallprompt", this.offer)
    window.removeEventListener("appinstalled", this.installed)
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
      outcome === "accepted" ? this.installed() : this.later()
    } catch {
      this.later()
    }
  }

  // « Plus tard », la croix, Échap ou le fond : la feuille se tait 3 jours sur ce téléphone.
  later() {
    this.remember()
    this.modal?.close()
  }

  dismissed(event) {
    if (event.target.id === "install_banner" && !this.done) this.remember()
  }

  installed() {
    this.done = true
    this.modal?.close()
  }

  remember() {
    try {
      localStorage.setItem(STORAGE_KEY, String(Date.now() + LATER_DAYS * DAY))
    } catch {}
  }

  laterUntil() {
    try {
      return Number(localStorage.getItem(STORAGE_KEY)) || 0
    } catch {
      return 0
    }
  }

  // Le contrôleur modal de la feuille se connecte juste après celui-ci : on l'attend une microtâche.
  show(target) {
    target.hidden = false
    queueMicrotask(() => this.modal?.open())
  }

  get modal() {
    const element = this.element.querySelector("[data-controller~='modal']")
    return element && this.application.getControllerForElementAndIdentifier(element, "modal")
  }
}
