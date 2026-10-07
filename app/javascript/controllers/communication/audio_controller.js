// ⚡ FRONT · communication/audio_controller — le bouton ▶ d'une annonce : écouter, arrêter, réécouter
// Rôle : un seul audio à la fois ; « écouté » retenu dans localStorage (try/catch) ; un échec est annoncé, jamais silencieux
// UDR  : 0071 (§3.4) · ADR : 0078
import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "lnclass.announcements.played"
const PLAY_EVENT = "communication--audio:play"
const STATUS_DELAY = 4000

export default class extends Controller {
  static targets = ["button", "player"]
  static values = { labels: Object, unavailable: String, key: String }

  connect() {
    this.played = this.remembered()
    this.pauseOthers = this.pauseOthers.bind(this)
    this.started = this.started.bind(this)
    this.stopped = this.stopped.bind(this)
    this.failed = this.failed.bind(this)
    window.addEventListener(PLAY_EVENT, this.pauseOthers)
    this.playerTarget.addEventListener("playing", this.started)
    this.playerTarget.addEventListener("pause", this.stopped)
    this.playerTarget.addEventListener("ended", this.stopped)
    this.playerTarget.addEventListener("error", this.failed)
    this.show(this.restingState)
  }

  disconnect() {
    window.removeEventListener(PLAY_EVENT, this.pauseOthers)
    this.playerTarget.removeEventListener("playing", this.started)
    this.playerTarget.removeEventListener("pause", this.stopped)
    this.playerTarget.removeEventListener("ended", this.stopped)
    this.playerTarget.removeEventListener("error", this.failed)
    this.playerTarget.pause()
    clearTimeout(this.statusTimer)
  }

  // À l'arrêt : lire (et arrêter les autres) ; en lecture : arrêter. Le fichier ne se télécharge qu'ici.
  toggle() {
    if (this.buttonTarget.dataset.state === "playing") {
      this.playerTarget.pause()
      return
    }

    window.dispatchEvent(new CustomEvent(PLAY_EVENT, { detail: { key: this.keyValue } }))
    this.show("playing")
    const playing = this.playerTarget.play()
    // Une lecture interrompue par pause() (un autre audio lancé) n'est pas un échec.
    if (playing) playing.catch((error) => { if (error.name !== "AbortError") this.failed() })
  }

  pauseOthers(event) {
    if (event.detail.key !== this.keyValue) this.playerTarget.pause()
  }

  started() {
    this.played = true
    this.remember()
    this.show("playing")
  }

  stopped() {
    this.show(this.restingState)
  }

  // Jamais d'échec silencieux : le message est annoncé (aria-live), puis effacé ; le bouton revient à l'arrêt.
  failed() {
    this.playerTarget.pause()
    this.show(this.restingState)
    const status = this.statusElement
    if (!status) return

    status.textContent = this.unavailableValue
    clearTimeout(this.statusTimer)
    this.statusTimer = setTimeout(() => { status.textContent = "" }, STATUS_DELAY)
  }

  show(state) {
    const [play, pause] = this.buttonTarget.querySelectorAll("svg")
    this.buttonTarget.dataset.state = state
    this.buttonTarget.setAttribute("aria-label", this.labelsValue[state])
    this.buttonTarget.classList.toggle("opacity-60", state === "played")
    play.classList.toggle("hidden", state === "playing")
    pause.classList.toggle("hidden", state !== "playing")
  }

  get restingState() {
    return this.played ? "played" : "new"
  }

  // Le statut est dans la colonne du texte de la carte, hors de l'élément du contrôleur (UDR-0071 §3.2).
  get statusElement() {
    return this.element.closest("article")?.querySelector("[data-communication--audio-target='status']")
  }

  // Sans stockage (navigation privée, stockage bloqué), l'état reste « new ».
  remembered() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")[this.keyValue] === true
    } catch {
      return false
    }
  }

  remember() {
    try {
      const played = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")
      played[this.keyValue] = true
      localStorage.setItem(STORAGE_KEY, JSON.stringify(played))
    } catch {
      // Rien à faire : l'écoute reste marquée pour cette page seulement.
    }
  }
}
