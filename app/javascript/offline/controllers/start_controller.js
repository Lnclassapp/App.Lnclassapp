// ⚡ FRONT · offline-start — le bouton « Commencer » d'un exercice : en ligne il range le paquet de corrigé, hors ligne il mène à la copie ou se désactive
// Rôle : en ligne, GET du paquet (même origine) rangé dans la base locale de la clé, puis la copie hors ligne est demandée une fois pour que le programme d'arrière-plan la garde ; hors ligne, paquet présent → visite de la copie, absent → bouton désactivé et message
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.4) · UDR : hors-connexion §3.3 · contrat store.js gelé · sans JavaScript ou en ligne, le formulaire part tel quel
import { Controller } from "../controller_base.js"
import { currentKey, deletePack, getPack, putPack } from "../store.js"

const REFUSALS = [ 402, 403, 404 ]

export default class extends Controller {
  static targets = [ "button", "unavailable" ]
  static values = { exercise: String, packUrl: String, copyUrl: String }

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
    this.refreshing = this.check()
    return this.refreshing
  }

  async check() {
    if (navigator.onLine === false) {
      this.packed = await this.hasPack()
      this.available(this.packed)
      return
    }

    this.available(true)
    await this.keepPack()
  }

  // Hors ligne seulement : mène à la copie sans réseau, quand le paquet est là ; sinon rien ne part.
  async go(event) {
    if (navigator.onLine !== false) return

    event.preventDefault()
    await this.refreshing
    if (!this.packed) return

    if (globalThis.Turbo) globalThis.Turbo.visit(this.copyUrlValue)
    else window.location.assign(this.copyUrlValue)
  }

  async hasPack() {
    try {
      const key = currentKey()
      return Boolean(key && await getPack(key, this.exerciseValue))
    } catch (error) {
      console.warn("exercice hors ligne : base locale illisible", error)
      return false
    }
  }

  // En ligne : d'abord la copie hors ligne (que le programme d'arrière-plan garde au passage), puis le paquet (questions, corrigé, jeton),
  // rangé seulement si la copie est là : un paquet sans copie mènerait hors ligne à une page vide.
  // Un refus d'accès (402, 403, 404) retire le paquet déjà rangé ; limite, panne ou réseau le gardent. Rien ne gêne le démarrage : l'exercice se fait en ligne.
  async keepPack() {
    try {
      const key = currentKey()
      if (!key) return

      const copy = await fetch(this.copyUrlValue, { credentials: "same-origin", headers: { Accept: "text/html" } })
      if (!copy.ok) return console.warn(`exercice hors ligne : copie non gardée (${copy.status})`)

      const response = await fetch(this.packUrlValue, { credentials: "same-origin", headers: { Accept: "application/json" } })
      if (response.ok) return await putPack(key, await response.json())

      if (REFUSALS.includes(response.status)) await deletePack(key, this.exerciseValue)
      else console.warn(`exercice hors ligne : paquet non rangé (${response.status})`)
    } catch (error) {
      console.warn("exercice hors ligne : paquet non rangé", error)
    }
  }

  available(ok) {
    this.buttonTarget.disabled = !ok
    this.buttonTarget.setAttribute("aria-disabled", String(!ok))
    this.unavailableTarget.hidden = ok
  }
}
