// ⚡ FRONT · push/push_subscription_controller.js — abonnement Web Push de l'élève : la carte d'invitation et la ligne « Notifications » du profil
// Rôle : [chargé à la demande, ADR-0051] montre la carte si le navigateur sait s'abonner ; la demande de permission n'a lieu qu'au clic « Oui » ; envoie l'abonnement (CSRF) ; sur le profil, accorde l'état du navigateur à celui du serveur
// ADR  : 0146 · UDR : 0186 (§3.1, §3.2) · la clé publique VAPID vient du serveur, jamais d'une constante
import { Controller } from "@hotwired/stimulus"

const csrfToken = () => document.querySelector("meta[name=csrf-token]")?.content || ""

// La clé publique VAPID (base64url) attendue par pushManager.subscribe, en octets.
const keyBytes = (base64Url) => {
  const padded = base64Url + "=".repeat((4 - (base64Url.length % 4)) % 4)
  const raw = atob(padded.replace(/-/g, "+").replace(/_/g, "/"))
  return Uint8Array.from(raw, (char) => char.charCodeAt(0))
}

export default class extends Controller {
  static values = { vapidKey: String, preferenceUrl: String, subscriptionsUrl: String, mode: String, state: String, messages: Object }
  static targets = ["accept", "content", "success", "status", "value", "cut"]

  connect() {
    if (!this.supported()) return

    if (this.modeValue === "card") {
      if (Notification.permission !== "denied") this.element.hidden = false
    } else if (this.stateValue === "on") {
      this.reconcile()
    }
  }

  supported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  // « Oui, me prévenir » / « Activer ici » : la boîte du navigateur n'apparaît qu'ici.
  async accept() {
    this.busy(true)
    try {
      const permission = await Notification.requestPermission()
      // Seul « denied » vaut « bloquées » : une boîte fermée sans réponse (« default ») laisse le bouton tel quel.
      if (permission === "denied") return this.blocked()
      if (permission !== "granted") return

      await this.subscribe()
      this.done()
    } catch (error) {
      console.warn(error)
      this.fail()
    } finally {
      this.busy(false)
    }
  }

  // « Réactiver » (profil) : efface l'interrupteur, puis s'abonne ; sans JS, le formulaire fait seulement la première moitié.
  async reactivate(event) {
    if (!this.supported()) return

    event.preventDefault()
    try {
      const body = new URLSearchParams({ intent: "turn_on" })
      const response = await fetch(this.preferenceUrlValue, { method: "PATCH", body, headers: this.headers({ Accept: "application/json" }) })
      if (!response.ok) throw new Error(response.status)
      this.stateValue = "on"
      await this.accept()
    } catch (error) {
      console.warn(error)
      this.fail()
    }
  }

  // Profil : l'état du serveur est « activé » ; le navigateur dit s'il est bloqué, déjà abonné, ou sur un autre appareil.
  async reconcile() {
    const permission = Notification.permission
    if (permission === "denied") return this.showBlocked()

    if (permission === "granted") {
      try {
        const registration = await navigator.serviceWorker.ready
        const existing = await registration.pushManager.getSubscription()
        await (existing ? this.send(existing) : this.subscribe())
      } catch (error) {
        console.warn(error)
        this.fail()
      }
    } else {
      if (this.hasValueTarget) this.valueTarget.textContent = this.messagesValue.other_device
      if (this.hasAcceptTarget) this.acceptTarget.hidden = false
    }
  }

  async subscribe() {
    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(this.vapidKeyValue) })
    await this.send(subscription)
  }

  async send(subscription) {
    const { endpoint, keys } = subscription.toJSON()
    const response = await fetch(this.subscriptionsUrlValue, {
      method: "POST",
      body: JSON.stringify({ endpoint, keys }),
      headers: this.headers({ "Content-Type": "application/json", Accept: "application/json" })
    })
    if (!response.ok) throw new Error(response.status)
  }

  headers(extra) {
    return { "X-CSRF-Token": csrfToken(), ...extra }
  }

  busy(on) {
    if (!this.hasAcceptTarget) return

    this.acceptTarget.disabled = on
    this.acceptTarget.toggleAttribute("aria-busy", on)
    if (on) {
      this.label = this.acceptTarget.textContent
      this.acceptTarget.textContent = this.messagesValue.loading
    } else if (this.label) {
      this.acceptTarget.textContent = this.label
    }
  }

  done() {
    if (this.modeValue === "card") {
      this.contentTarget.hidden = true
      this.successTarget.hidden = false
      this.statusTarget.textContent = ""
    } else {
      this.valueTarget.textContent = this.messagesValue.activated
      if (this.hasAcceptTarget) this.acceptTarget.hidden = true
      this.statusTarget.textContent = ""
    }
  }

  blocked() {
    if (this.modeValue === "card") {
      this.statusTarget.textContent = this.messagesValue.blocked
      if (this.hasAcceptTarget) this.acceptTarget.hidden = true
    } else {
      this.showBlocked()
    }
  }

  showBlocked() {
    this.valueTarget.textContent = this.messagesValue.blocked
    this.statusTarget.textContent = this.messagesValue.blocked_detail
    if (this.hasAcceptTarget) this.acceptTarget.hidden = true
  }

  fail() {
    this.statusTarget.textContent = this.messagesValue.error
    this.statusTarget.classList.add("text-error")
  }
}
