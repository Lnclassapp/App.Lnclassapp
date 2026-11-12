// ⚡ FRONT · offline-queue — « N copies à envoyer », « Envoi… », copies refusées (« J'ai compris »), « Copie envoyée · N % » sur l'accueil élève
// Rôle : lit la file de la clé de la page (jamais d'une autre) ; une copie envoyée est dite une fois puis retirée de la file ; tout texte est posé en textContent
// UDR  : hors-connexion §3.6 · ADR : hors-connexion §4.5
import { Controller } from "@hotwired/stimulus"
import { currentKey, listCopies, deleteCopy, getPack } from "../offline/store.js"
import { QUEUE_EVENT, SENDING_EVENT } from "../offline/sync.js"

export default class extends Controller {
  static targets = [ "pending", "pendingText", "synced", "rejected", "rejectedRow" ]
  static values = { pendingOne: String, pendingOther: String, sending: String, synced: String, rejected: Object }

  connect() {
    this.sent = []
    this.sending = false
    this.onSending = () => { this.sending = true; return this.refresh() }
    this.onQueue = () => { this.sending = false; return this.refresh() }
    window.addEventListener(SENDING_EVENT, this.onSending)
    window.addEventListener(QUEUE_EVENT, this.onQueue)
    this.refresh()
  }

  disconnect() {
    window.removeEventListener(SENDING_EVENT, this.onSending)
    window.removeEventListener(QUEUE_EVENT, this.onQueue)
  }

  async refresh() {
    const key = currentKey()
    if (!key) { this.element.hidden = true; return }

    let copies
    try {
      copies = await listCopies(key)
    } catch (error) {
      console.error("File des copies hors ligne illisible", error)
      return
    }
    await this.collectSent(key, copies)
    const pending = copies.filter((copy) => copy.status === "pending")
    const rejected = copies.filter((copy) => copy.status === "rejected")

    this.showPending(pending.length)
    this.showSent()
    await this.showRejected(key, rejected)
    this.element.hidden = pending.length + rejected.length + this.sent.length === 0
  }

  // Dite une fois : la copie envoyée sort de la file dès qu'elle est lue ; la ligne reste le temps de la page.
  async collectSent(key, copies) {
    for (const copy of copies.filter((item) => item.status === "synced")) {
      this.sent.push(this.syncedValue.replace("%{percent}", copy.server_percent))
      await deleteCopy(key, copy.client_copy_id)
    }
  }

  showPending(count) {
    this.pendingTarget.hidden = count === 0
    if (count === 0) return

    const text = this.sending ? this.sendingValue : (count === 1 ? this.pendingOneValue : this.pendingOtherValue.replace("%{count}", count))
    this.pendingTextTarget.textContent = text
  }

  showSent() {
    this.syncedTarget.hidden = this.sent.length === 0
    this.syncedTarget.replaceChildren(...this.sent.map((text) => {
      const line = document.createElement("p")
      line.textContent = text
      return line
    }))
  }

  async showRejected(key, rejected) {
    const rows = []
    for (const copy of rejected) rows.push(await this.row(key, copy))
    this.rejectedTarget.hidden = rows.length === 0
    this.rejectedTarget.replaceChildren(...rows)
  }

  async row(key, copy) {
    const row = this.rejectedRowTarget.content.firstElementChild.cloneNode(true)
    row.querySelector("[data-role='reason']").textContent = this.rejectedValue[copy.reason] || this.rejectedValue.invalid || ""
    row.querySelector("[data-role='title']").textContent = await this.titleOf(key, copy)
    row.querySelector("button").onclick = async () => {
      await deleteCopy(key, copy.client_copy_id)
      await this.refresh()
    }
    return row
  }

  // Le titre se lit dans le paquet gardé de l'exercice, quand il en porte un.
  async titleOf(key, copy) {
    try {
      const title = (await getPack(key, copy.exercise_public_id))?.title
      return typeof title === "string" ? title : ""
    } catch {
      return ""
    }
  }
}
