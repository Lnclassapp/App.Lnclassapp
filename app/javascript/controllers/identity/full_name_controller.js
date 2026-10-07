// ⚡ FRONT · identity/full_name_controller — aperçu du découpage du « Nom complet » : premier mot = nom, le reste = prénoms
// Rôle : montre « Nom : … · Prénom(s) : … » pendant la frappe ; « Corriger » s'ouvre pré-rempli ; le serveur découpe sans JavaScript
// ADR  : 0037, 0051, 0082 · UDR : 0078 (§3.3)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "lastOut", "firstOut", "editor", "lastName", "firstName"]

  // Un re-rendu 422 est un morphing : il remet le `hidden` du serveur sans reconnecter le contrôleur.
  connect() {
    this.preview()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.refresh)
  }

  refresh = () => this.preview()

  // Les valeurs passent par textContent, jamais par du HTML. Les champs corrigés ne sont jamais touchés ici.
  preview() {
    const parts = this.split()
    this.previewTarget.hidden = !parts
    if (!parts) return

    this.lastOutTarget.textContent = parts[0]
    this.firstOutTarget.textContent = parts[1]
  }

  // À l'ouverture de « Corriger », deux champs vides reçoivent le découpage courant ; la fermeture ne vide rien.
  fill() {
    if (!this.editorTarget.open || this.lastNameTarget.value || this.firstNameTarget.value) return

    const parts = this.split()
    if (!parts) return

    this.lastNameTarget.value = parts[0]
    this.firstNameTarget.value = parts[1]
  }

  // Comme Entities::Identity::FullName.split : espaces réduits, coupe au premier espace, rien sous deux mots.
  split() {
    const words = this.inputTarget.value.trim().split(/\s+/).filter(Boolean)
    return words.length < 2 ? null : [words[0], words.slice(1).join(" ")]
  }
}
