// ⚡ FRONT · school/school_search_controller — le champ « Ton établissement » : recherche pendant la frappe dans le frame « school_results »
// Rôle : 300 ms après la frappe, 2 lettres au moins, pose le src du frame ; le résultat coché replie la liste et émet « picked » ; une nouvelle saisie émet « cleared »
// ADR  : 0142-recherche-etablissement · UDR : 0177-champ-etablissement (§3 Comportement), sur le modèle de search_controller
import { Controller } from "@hotwired/stimulus"

// Comme Queries::School::SchoolSearchQuery.words : la saisie compte sans ses espaces ni sa ponctuation.
const MIN_LENGTH = 2

export default class extends Controller {
  static targets = ["input", "frame", "error"]
  static values = { url: String, delay: { type: Number, default: 300 } }

  disconnect() {
    clearTimeout(this.timeout)
  }

  // Sur `input` : le délai repart à chaque frappe ; un choix fait se retire aussitôt (la liste va changer).
  queue() {
    clearTimeout(this.timeout)
    this.release()
    this.timeout = setTimeout(() => this.search(), this.delayValue)
  }

  // Entrée : jamais l'envoi du formulaire hôte, la recherche tout de suite.
  now(event) {
    event.preventDefault()
    clearTimeout(this.timeout)
    this.release()
    this.search()
  }

  search() {
    const term = this.inputTarget.value.trim()
    if (term.replace(/[^\p{L}\p{N}]/gu, "").length < MIN_LENGTH) return this.clear()

    const url = new URL(this.urlValue, document.baseURI)
    url.searchParams.set("q", term)
    if (this.frameTarget.getAttribute("src") === url.toString()) this.frameTarget.reload()
    else this.frameTarget.src = url.toString()
  }

  // Un résultat coché : la liste se replie sur lui, les hôtes chargent la suite (niveaux, étape 2).
  pick({ target }) {
    this.optionTargets.forEach((option) => { if (!option.contains(target)) option.remove() })
    this.frameTarget.querySelector("[data-school--school-search-target='more']")?.remove()
    this.dispatch("picked", { detail: { publicId: target.value } })
  }

  // Réponse sans son frame (404, 500) ou réseau coupé : l'état d'erreur, « Réessayer » relance la même recherche.
  missing(event) {
    event.preventDefault?.()
    this.release()
    const error = this.errorTarget.content.cloneNode(true)
    error.querySelectorAll("a").forEach((link) => {
      link.setAttribute("href", this.frameTarget.getAttribute("src") || "")
    })
    this.frameTarget.replaceChildren(error)
  }

  clear() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren()
  }

  // Le choix précédent n'est plus envoyé : il disparaît avec la liste, et les hôtes vident ce qui en dépendait.
  release() {
    const checked = this.frameTarget.querySelector("input[type=radio]:checked")
    if (!checked) return

    checked.checked = false
    this.dispatch("cleared")
  }

  get optionTargets() {
    return [...this.frameTarget.querySelectorAll("[data-school--school-search-target='option']")]
  }
}
