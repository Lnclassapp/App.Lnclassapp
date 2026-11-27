// ⚡ FRONT · digits_only_controller — un champ de numéro ou de code secret ne garde que des chiffres, pendant la frappe
// Rôle : à chaque saisie (frappe, collage, dictée), tout ce qui n'est pas un chiffre est retiré et la longueur bornée à maxlength ; posé par ui_field sur tout champ inputmode="numeric"
// UDR  : 0189-connexion-numero-d-abord (amendement du 2026-11-27, §3.7)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.clean = this.clean.bind(this)
    this.element.addEventListener("input", this.clean)
    this.clean()
  }

  disconnect() {
    this.element.removeEventListener("input", this.clean)
  }

  clean() {
    const field = this.element
    const max = field.maxLength > 0 ? field.maxLength : Infinity
    const value = field.value.replace(/\D/g, "").slice(0, max)
    if (value === field.value) return

    field.value = value
    if (field.type !== "password" && field === document.activeElement) field.setSelectionRange(value.length, value.length)
  }
}
