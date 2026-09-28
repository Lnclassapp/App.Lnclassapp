// ⚡ FRONT · identity/photo_picker_controller — recadre la photo choisie en carré, l'allège et la montre avant l'envoi
// Rôle : canvas 512 px au plus, WebP (JPEG à défaut) à 80 % ; le fichier du champ est remplacé ; sans recadrage, le serveur tranche
// ADR  : 0060 · UDR : 0047
import { Controller } from "@hotwired/stimulus"

const SIZE = 512
const QUALITY = 0.8

export default class extends Controller {
  static targets = ["input", "current", "preview"]

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
    this.pending = this.shrink(file)
      .then((photo) => this.use(photo))
      // Image illisible ici (PDF, format inconnu, navigateur ancien) : le fichier part tel quel et le serveur l'explique.
      .catch(() => {})
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
    const context = canvas.getContext("2d")
    // Fond du token blanc sous une image transparente : sans lui, le JPEG la rendrait noire.
    context.fillStyle = getComputedStyle(document.documentElement).getPropertyValue("--color-white")
    context.fillRect(0, 0, size, size)
    context.drawImage(image, (width - side) / 2, (height - side) / 2, side, side, 0, 0, size, size)
    return canvas
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

  revokePreview() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }
}
