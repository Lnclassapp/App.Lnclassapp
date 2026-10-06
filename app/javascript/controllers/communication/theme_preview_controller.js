// ⚡ FRONT · communication/theme_preview_controller — aperçu du thème choisi sur les illustrations du formulaire d'annonce
// Rôle : au changement de thème, pose data-announcement-theme sur le fieldset de l'illustration, dont les dessins se recolorent
// UDR  : 0075 (§3.3) · sans JavaScript : rien ne se passe, l'aperçu reste en « Ciel »
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // illustrations : l'id du fieldset de l'illustration, voisin de celui des thèmes (hors de cet élément).
  static values = { illustrations: String }

  // Après un formulaire refusé ou en modification, le thème coché n'est pas forcément « Ciel ».
  connect() {
    const checked = this.element.querySelector("input[type=radio]:checked")
    if (checked) this.apply(checked.value)
  }

  preview(event) {
    this.apply(event.target.value)
  }

  apply(theme) {
    const illustrations = document.getElementById(this.illustrationsValue)
    if (illustrations) illustrations.dataset.announcementTheme = theme
  }
}
