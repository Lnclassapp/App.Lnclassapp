// ⚡ FRONT · identity/full_name_controller — aperçu du « Nom complet » : premier mot = nom, le reste = prénoms, ou la correction
// Rôle : aperçu « Nom : … · Prénom(s) : … » ; « Corriger » ouvert, l'aperçu suit les champs corrigés, fermé ils ne partent pas
// ADR  : 0037, 0051, 0082 · UDR : 0078 (§3.3)
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "lastOut", "firstOut", "editor", "lastName", "firstName"]

  // Un re-rendu 422 est un morphing : il remet le `hidden` du serveur sans reconnecter le contrôleur.
  connect() {
    this.syncEditor()
    this.preview()
    document.addEventListener("turbo:morph", this.refresh)
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.refresh)
  }

  refresh = () => {
    this.syncEditor()
    this.preview()
  }

  // « Corriger » fermé : ses deux champs ne partent pas, le serveur découpe le nom complet comme l'aperçu. Sans JavaScript,
  // rien n'est désactivé et la règle serveur (les deux champs remplis font foi) s'applique.
  syncEditor() {
    const closed = !this.editorTarget.open
    this.lastNameTarget.disabled = closed
    this.firstNameTarget.disabled = closed
  }

  // La saisie dans un champ corrigé met l'aperçu à jour ; la vue ne porte l'action que sur le nom complet.
  lastNameTargetConnected(field) {
    field.addEventListener("input", this.refresh)
  }

  firstNameTargetConnected(field) {
    field.addEventListener("input", this.refresh)
  }

  lastNameTargetDisconnected(field) {
    field.removeEventListener("input", this.refresh)
  }

  firstNameTargetDisconnected(field) {
    field.removeEventListener("input", this.refresh)
  }

  // Les valeurs passent par textContent, jamais par du HTML. Les champs corrigés ne sont jamais touchés ici.
  preview() {
    const parts = this.corrected() || this.split()
    this.previewTarget.hidden = !parts
    if (!parts) return

    this.lastOutTarget.textContent = parts[0]
    this.firstOutTarget.textContent = parts[1]
  }

  // À l'ouverture de « Corriger », deux champs vides reçoivent le découpage courant ; la fermeture ne vide rien. Dans les
  // deux cas, l'aperçu change de source.
  fill() {
    this.syncEditor()
    if (this.editorTarget.open && !this.lastNameTarget.value && !this.firstNameTarget.value) {
      const parts = this.split()
      if (parts) [this.lastNameTarget.value, this.firstNameTarget.value] = parts
    }
    this.preview()
  }

  // « Corriger » ouvert et les deux champs remplis : ils font foi, comme côté serveur (ADR-0082 §4.4). Sinon nil.
  corrected() {
    if (!this.editorTarget.open) return null

    const parts = [this.lastNameTarget.value, this.firstNameTarget.value].map((value) => value.trim().split(/\s+/).join(" "))
    return parts.every(Boolean) ? parts : null
  }

  // Comme Entities::Identity::FullName.split : espaces réduits, coupe au premier espace, rien sous deux mots.
  split() {
    const words = this.inputTarget.value.trim().split(/\s+/).filter(Boolean)
    return words.length < 2 ? null : [words[0], words.slice(1).join(" ")]
  }
}
