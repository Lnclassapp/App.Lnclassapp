// ⚡ FRONT · identity/photo_picker_controller — recadre la photo choisie en carré, l'allège et la montre avant l'envoi
// Rôle : canvas 512 px au plus, WebP (JPEG à défaut) à 80 % ; image vide refusée ici ; illisible ici, le serveur tranche
// ADR  : 0060 · UDR : 0047
import { Controller } from "@hotwired/stimulus"

const SIZE = 512
const QUALITY = 0.8

// L'image se décode, mais en rien (0 × 0, ou aucun pixel visible : un WebP réduit à son en-tête, par exemple).
class EmptyImage extends Error {}

export default class extends Controller {
  static targets = ["input", "current", "preview", "unreadable"]

  disconnect() {
    this.revokePreview()
  }

  // Un envoi pendant le recadrage attend sa fin, puis repart avec le fichier allégé.
  hold(event) {
    if (!this.pending) return

    event.preventDefault()
    event.stopImmediatePropagation()
    const submitter = event.submitter
    this.pending.finally(() => this.element.requestSubmit(submitter))
  }

  pick() {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.element.setAttribute("aria-busy", "true")
    this.showUnreadable(false)
    this.pending = this.shrink(file)
      .then((photo) => this.use(photo))
      // Image vide : refusée ici, le champ est vidé. Image illisible ici (PDF, format inconnu, navigateur ancien) : le
      // fichier part tel quel et le serveur l'explique.
      .catch((error) => {
        if (error instanceof EmptyImage) this.refuse()
      })
      .finally(() => {
        this.pending = null
        this.element.removeAttribute("aria-busy")
      })
  }

  async shrink(file) {
    const url = URL.createObjectURL(file)
    try {
      const image = new Image()
      image.src = url
      await image.decode()
      if (!image.naturalWidth || !image.naturalHeight) throw new EmptyImage()
      return await this.encode(this.crop(image))
    } finally {
      URL.revokeObjectURL(url)
    }
  }

  // Carré centré, jamais agrandi. Le canvas ne recopie ni l'Exif ni la position GPS de la photo.
  crop(image) {
    const width = image.naturalWidth
    const height = image.naturalHeight
    const side = Math.min(width, height)
    const size = Math.min(SIZE, side)
    const canvas = document.createElement("canvas")
    canvas.width = size
    canvas.height = size
    const context = canvas.getContext("2d", { willReadFrequently: true })
    context.drawImage(image, (width - side) / 2, (height - side) / 2, side, side, 0, 0, size, size)
    if (!this.visible(context, size)) throw new EmptyImage()

    // Fond du token blanc sous les parties transparentes : sans lui, le JPEG les rendrait noires.
    context.globalCompositeOperation = "destination-over"
    context.fillStyle = getComputedStyle(document.documentElement).getPropertyValue("--color-white")
    context.fillRect(0, 0, size, size)
    return canvas
  }

  // Au moins un pixel non transparent : sinon, on enverrait un carré blanc.
  visible(context, size) {
    const pixels = context.getImageData(0, 0, size, size).data
    for (let alpha = 3; alpha < pixels.length; alpha += 4) {
      if (pixels[alpha]) return true
    }
    return false
  }

  // WebP d'abord ; un navigateur qui ne sait pas l'écrire rend un PNG : on repasse alors en JPEG.
  async encode(canvas) {
    const webp = await this.toBlob(canvas, "image/webp")
    if (webp.type === "image/webp") return new File([webp], "photo.webp", { type: webp.type })

    const jpeg = await this.toBlob(canvas, "image/jpeg")
    return new File([jpeg], "photo.jpg", { type: "image/jpeg" })
  }

  toBlob(canvas, type) {
    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error(type))), type, QUALITY)
    })
  }

  use(photo) {
    const files = new DataTransfer()
    files.items.add(photo)
    this.inputTarget.files = files.files

    this.revokePreview()
    this.previewUrl = URL.createObjectURL(photo)
    this.previewTarget.src = this.previewUrl
    this.previewTarget.hidden = false
    this.currentTarget.hidden = true
  }

  // Le champ est vidé : « Enregistrer » ne peut rien envoyer, et le message dit pourquoi.
  refuse() {
    this.inputTarget.value = ""
    this.previewTarget.hidden = true
    this.currentTarget.hidden = false
    this.showUnreadable(true)
  }

  showUnreadable(shown) {
    this.unreadableTarget.hidden = !shown
    const describedBy = (this.inputTarget.getAttribute("aria-describedby") || "").split(" ").filter((id) => id && id !== this.unreadableTarget.id)
    if (shown) describedBy.push(this.unreadableTarget.id)
    this.inputTarget.setAttribute("aria-describedby", describedBy.join(" "))
    if (shown) this.inputTarget.setAttribute("aria-invalid", "true")
    else if (!describedBy.some((id) => id.endsWith("_error"))) this.inputTarget.removeAttribute("aria-invalid")
  }

  revokePreview() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }
}
