// ⚡ FRONT · bridge/account_controller — composant de pont « account » : donne à la coque Android l'avatar de l'élève
// Rôle : envoie initiales, photo, adresses du panneau et de l'aide à la barre du haut native ; hors coque, Stimulus ne le charge pas
// UDR  : 0080 (§3.3) · ADR : 0084 (§4.2)
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "account"
  static values = { initials: String, photoUrl: String, menuUrl: String, helpUrl: String }

  connect() {
    super.connect()
    // Adresses absolues : la coque les route telles quelles. Sans photo, la clé est absente et la coque peint les initiales.
    this.send("connect", {
      initials: this.initialsValue,
      photoUrl: this.hasPhotoUrlValue ? this.absolute(this.photoUrlValue) : undefined,
      menuUrl: this.absolute(this.menuUrlValue),
      helpUrl: this.absolute(this.helpUrlValue)
    })
  }

  absolute(path) {
    return new URL(path, window.location.href).href
  }
}
