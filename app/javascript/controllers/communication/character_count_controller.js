// ⚡ FRONT · communication/character_count_controller — compteur de caractères du résumé d'un article (UDR-0067 §3.3)
// Rôle : « 42 / 200 », ambre à 20 restants, rouge à la limite ; l'annonce ne change qu'au franchissement d'un seuil
// UDR  : 0067 · sans JavaScript : le chiffre rendu par le serveur reste, maxlength borne la saisie
import { Controller } from "@hotwired/stimulus"

const NEAR = 20
// Classes de la palette écrites en entier pour que Tailwind les compile (UDR-0067 §3.9).
const TONES = { calm: "text-mute", near: "text-warning", full: "text-error" }

export default class extends Controller {
  static targets = ["input", "count", "status"]
  // near : « Il reste %{count} caractères. » ; full : « Limite atteinte : 200 caractères. » (rendus par le serveur).
  static values = { max: Number, near: String, full: String }

  connect() {
    this.level = this.levelOf(this.inputTarget.value.length)
    this.render()
  }

  update() {
    const level = this.levelOf(this.inputTarget.value.length)
    this.render()
    if (level === this.level) return

    // Annoncer chaque frappe couvrirait la lecture : seul le passage d'un seuil à l'autre est dit.
    this.level = level
    this.statusTarget.textContent = this.announcement(level)
  }

  render() {
    const length = this.inputTarget.value.length
    this.countTarget.textContent = `${length} / ${this.maxValue}`
    this.countTarget.classList.remove(...Object.values(TONES))
    this.countTarget.classList.add(TONES[this.levelOf(length)])
  }

  levelOf(length) {
    const left = this.maxValue - length
    if (left <= 0) return "full"
    return left <= NEAR ? "near" : "calm"
  }

  announcement(level) {
    if (level === "full") return this.fullValue.replace("%{max}", this.maxValue)
    if (level === "near") return this.nearValue.replace("%{count}", this.maxValue - this.inputTarget.value.length)
    return ""
  }
}
