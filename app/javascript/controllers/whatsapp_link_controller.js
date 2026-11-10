// ⚡ FRONT · whatsapp-link — garde le lien « Ouvrir dans WhatsApp », le texte à copier et le compteur d'accord avec le brouillon modifié
// Rôle : à chaque saisie ou changement de destinataire, recalcule https://wa.me/<indicatif><numéro>?text=<texte encodé> ; l'application n'envoie rien
// UDR  : XXXX (assistants du suivi, « Brouillon WhatsApp ») · ADR : 0051
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text", "recipient", "link", "counter"]
  static values = {
    base: { type: String, default: "https://wa.me/" },
    prefix: { type: String, default: "225" },
    max: { type: Number, default: 600 },
    counterTemplate: String,
  }

  connect() {
    this.update()
  }

  update() {
    const text = this.textTarget.value
    if (this.hasCounterTarget && this.counterTemplateValue) {
      this.counterTarget.textContent = this.counterTemplateValue
        .replace("%{count}", text.length)
        .replace("%{max}", this.maxValue)
    }
    // Le bouton « Copier » (contrôleur clipboard) copie la valeur qu'on lui a donnée : on la tient à jour.
    this.element.querySelectorAll("[data-controller~='clipboard']").forEach((copy) => { copy.dataset.clipboardTextValue = text })
    if (this.hasLinkTarget) this.linkTarget.setAttribute("href", this.href(text))
  }

  href(text) {
    const phone = this.hasRecipientTarget ? this.recipientTarget.value : ""
    return `${this.baseValue}${this.prefixValue}${phone}?text=${encodeURIComponent(text)}`
  }
}
