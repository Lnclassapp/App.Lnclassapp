// ⚡ FRONT · offline-session — donne la clé d'appareil au programme d'arrière-plan, purge l'ancienne clé, vide tout à la déconnexion
// Rôle : clé → postMessage ; clé changée → purge de l'ancienne (file non envoyée gardée) ; formulaire DELETE /session → runBeforePurge puis purgeKey, puis la requête part
// ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.2, menace P1, P2, P4) · contrat du plan « Contrats JavaScript gelés »
import { Controller } from "@hotwired/stimulus"
import { currentKey, rememberKey, purgeKey, runBeforePurge } from "../offline/store.js"

const LOGOUT_PATH = "/session"
// L'envoi de la file ne retient jamais la déconnexion plus longtemps.
const BEFORE_PURGE_TIMEOUT_MS = 10_000

export default class extends Controller {
  connect() {
    this.released = new WeakSet()
    this.leaving = new WeakSet()
    this.onSubmit = this.onSubmit.bind(this)
    this.onControllerChange = this.onControllerChange.bind(this)
    document.addEventListener("submit", this.onSubmit, true)
    navigator.serviceWorker?.addEventListener?.("controllerchange", this.onControllerChange)

    this.key = currentKey()
    if (this.key) this.start(this.key).catch((error) => console.error("lnclass: clé d'appareil non prise en compte", error))
  }

  disconnect() {
    document.removeEventListener("submit", this.onSubmit, true)
    navigator.serviceWorker?.removeEventListener?.("controllerchange", this.onControllerChange)
  }

  async start(key) {
    const sent = this.sendKey(key).catch((error) => console.error("lnclass: clé non envoyée au programme d'arrière-plan", error))
    await this.purgePrevious(key)
    await sent
  }

  // Une clé différente de la précédente : on vide ce qui appartenait à l'ancienne, sauf sa file de copies non envoyées.
  async purgePrevious(key) {
    try {
      const previous = rememberKey(key)
      if (previous && previous !== key) await purgeKey(previous, { keepQueue: true })
    } catch (error) {
      console.error("lnclass: purge de l'ancienne clé incomplète", error)
    }
  }

  async sendKey(key) {
    const container = navigator.serviceWorker
    if (!container) return

    const registration = await container.ready
    this.post(registration.active || container.controller, key)
  }

  onControllerChange() {
    if (this.key) this.post(navigator.serviceWorker.controller, this.key)
  }

  post(worker, key) {
    worker?.postMessage({ type: "lnclass:key", key })
  }

  // Déconnexion : la requête est retenue le temps de vider ce que Lnclass garde pour cette clé, puis relancée (Turbo la reprend).
  onSubmit(event) {
    const form = event.target
    if (this.released.has(form) || !this.logoutForm(form)) return

    const key = this.key || currentKey()
    if (!key) return

    event.preventDefault()
    event.stopImmediatePropagation()
    if (this.leaving.has(form)) return

    this.leaving.add(form)
    this.leave(form, event.submitter, key)
  }

  logoutForm(form) {
    if (form?.tagName !== "FORM") return false

    try {
      const method = form.querySelector('input[name="_method"]')?.value || form.method
      return new URL(form.action, globalThis.location?.href || "https://lnclass.invalid").pathname === LOGOUT_PATH && String(method).toLowerCase() === "delete"
    } catch {
      return false
    }
  }

  async leave(form, submitter, key) {
    // Si la file n'a pas pu partir, on garde ses copies (keepQueue) : mieux vaut un reste sur le téléphone qu'une copie perdue.
    let keepQueue = false
    try {
      await this.withTimeout(runBeforePurge())
    } catch (error) {
      keepQueue = true
      console.error("lnclass: file de copies non envoyée avant la déconnexion", error)
    }
    try {
      await purgeKey(key, { keepQueue })
    } catch (error) {
      console.error("lnclass: purge à la déconnexion incomplète", error)
    }

    this.leaving.delete(form)
    this.released.add(form)
    this.resubmit(form, submitter)
  }

  withTimeout(promise) {
    let timer
    const timeout = new Promise((_, reject) => { timer = setTimeout(() => reject(new Error("délai dépassé")), BEFORE_PURGE_TIMEOUT_MS) })
    return Promise.race([promise, timeout]).finally(() => clearTimeout(timer))
  }

  resubmit(form, submitter) {
    if (typeof form.requestSubmit !== "function") return form.submit()

    try {
      form.requestSubmit(submitter?.form === form ? submitter : undefined)
    } catch {
      form.submit()
    }
  }
}
