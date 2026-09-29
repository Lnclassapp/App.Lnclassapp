// ⚡ FRONT · search_controller — recherche pendant la frappe sur un formulaire GET qui vise un Turbo Frame
// Rôle : envoie après `delay` ms sans frappe (URL remplacée, pas d'historique empilé) ; une liste déroulante part au changement
// UDR  : 0054 (§3.9) · sans JavaScript, le bouton « Filtrer » reste ; Turbo annule la requête précédente du frame
import { Controller } from "@hotwired/stimulus"

// Numéro complet (ADR-0050) : 10 chiffres, ou 13 commençant par 225, ou 15 commençant par 00225.
const FULL_NUMBER = /^(\d{10}|225\d{10}|00225\d{10})$/

export default class extends Controller {
  static targets = ["button"]
  static values = { delay: { type: Number, default: 300 }, minLength: { type: Number, default: 2 }, digits: Boolean }

  connect() {
    this.buttonTargets.forEach((button) => { button.hidden = true })
    this.restoreAction = this.restoreAction.bind(this)
    this.element.addEventListener("turbo:submit-end", this.restoreAction)
  }

  disconnect() {
    clearTimeout(this.timeout)
    this.element.removeEventListener("turbo:submit-end", this.restoreAction)
  }

  // Sur `input` du champ texte : le délai repart à chaque frappe.
  queue(event) {
    const field = event.target
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      if (this.ready(field.value)) this.send("replace")
    }, this.delayValue)
  }

  // Sur `change` d'une liste déroulante : envoi immédiat, qui garde l'action de navigation du formulaire.
  submit() {
    clearTimeout(this.timeout)
    this.send(null)
  }

  ready(raw) {
    if (this.digitsValue) return FULL_NUMBER.test(raw.replace(/\D/g, ""))

    const value = raw.trim()
    return value.length === 0 || value.length >= this.minLengthValue
  }

  // `data-turbo-action="replace"` le temps de l'envoi : Turbo le lit à la réponse, puis l'action d'origine revient.
  send(action) {
    if (action) {
      this.previousAction = this.element.getAttribute("data-turbo-action")
      this.element.setAttribute("data-turbo-action", action)
    }
    this.element.requestSubmit()
  }

  restoreAction() {
    if (this.previousAction === undefined) return

    if (this.previousAction === null) this.element.removeAttribute("data-turbo-action")
    else this.element.setAttribute("data-turbo-action", this.previousAction)
    this.previousAction = undefined
  }
}
