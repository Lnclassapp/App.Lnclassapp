// ⚡ FRONT · modal_controller — ouvre et ferme une <dialog> native, y compris chargée dans le frame « modal »
// Rôle : showModal() fournit le piège du focus et Échap ; fond cliquable ; fermeture après un envoi réussi ; frame vidé à la fermeture
// UDR  : 0005, 0006, 0046, 0054, 0061 · émet modal:opened (auto-focus) ; `documentTitle` nomme l'onglet ; rend le focus au déclencheur
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean, documentTitle: String }

  // Une modale servie ouverte (open: true) s'ouvre dès son arrivée : c'est le cas du contenu chargé dans le frame « modal ».
  connect() {
    this.openObserver = new MutationObserver(() => this.syncOpen())
    this.openObserver.observe(this.dialogTarget, { attributes: true, attributeFilter: ["open"] })
    if (this.openValue) this.open()
  }

  // Retirée ouverte (re-rendu 422 dans le frame) : l'onglet reprend son titre, sauf si une navigation l'a déjà changé.
  disconnect() {
    this.openObserver.disconnect()
    this.restoreTitle()
  }

  // Un morphing Turbo (replace method: morph, refresh) retire l'attribut `open` d'une boîte ouverte par showModal() :
  // elle quitte l'écran mais reste dans la couche supérieure, et toute la page devient inerte. On la referme vraiment.
  syncOpen() {
    const dialog = this.dialogTarget
    if (dialog.open || !dialog.matches(":modal")) return

    dialog.setAttribute("open", "")
    dialog.close()
  }

  // Servie ouverte dès le HTML (lisible sans JavaScript), la <dialog> l'est sans être modale : elle est rouverte par
  // showModal(), qui refuse une boîte déjà ouverte, pour piéger le focus et poser le fond.
  // UDR-0061 : un déclencheur-lien (repli sans JavaScript, `trigger_href`) ne navigue pas ; il est mémorisé pour le focus.
  open(event) {
    event?.preventDefault()
    const dialog = this.dialogTarget
    if (dialog.open && dialog.matches(":modal")) return

    this.opener = event?.currentTarget ?? (document.activeElement === document.body ? null : document.activeElement)
    dialog.removeAttribute("open")
    dialog.showModal()
    this.nameTab()
    this.dispatch("opened", { target: dialog })
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  // Le clic tombe sur la <dialog> elle-même seulement hors de son contenu, c'est-à-dire sur le fond.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // Envoi réussi (réponse Turbo Stream) : on ferme. Un 422 re-rend la modale dans le frame, qui se rouvre avec ses erreurs.
  submitEnd(event) {
    if (event.detail.success) this.close()
  }

  // Chargée dans le frame « modal », la modale fermée libère le frame : le même lien pourra la recharger.
  closed() {
    this.restoreTitle()
    this.restoreFocus()
    const frame = this.element.closest("turbo-frame#modal")
    // Une boîte déjà rouverte (open() juste après son arrivée) n'est pas fermée : le frame garde son contenu.
    if (!frame || this.dialogTarget.open) return

    frame.removeAttribute("src")
    frame.replaceChildren()
  }

  // UDR-0061 §3.7 : le navigateur rend le focus au déclencheur d'une boîte ouverte par showModal() ; à défaut (focus
  // laissé sur <body>, navigateurs de l'ADR-0051), le contrôleur le fait.
  restoreFocus() {
    const opener = this.opener
    this.opener = null
    if (!opener?.isConnected || this.dialogTarget.open) return
    if (document.activeElement && document.activeElement !== document.body) return

    opener.focus()
  }

  // UDR-0054 §3.1 : une confirmation n'a pas de `documentTitle` et laisse l'onglet tel quel.
  nameTab() {
    if (!this.documentTitleValue || this.previousTitle !== undefined) return

    this.previousTitle = document.title
    document.title = this.documentTitleValue
  }

  restoreTitle() {
    if (this.previousTitle === undefined) return

    if (document.title === this.documentTitleValue) document.title = this.previousTitle
    this.previousTitle = undefined
  }
}
