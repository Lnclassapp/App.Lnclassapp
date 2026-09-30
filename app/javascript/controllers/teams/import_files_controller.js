// ⚡ FRONT · teams/import_files_controller — résumé de la sélection de fichiers dans la modale d'import
// Rôle : nombre, taille totale et noms des fichiers choisis ; un dépassement de limite désactive l'envoi (le serveur recontrôle)
// ADR  : 0068 · UDR : 0055 §3.1 · libellés passés en data-*-text-value, jamais en dur ; noms écrits en textContent
import { Controller } from "@hotwired/stimulus"

const KILOBYTE = 1024
const MEGABYTE = 1024 * 1024

export default class extends Controller {
  static targets = ["input", "count", "list", "error", "message"]
  static values = {
    maxFiles: Number, maxTotalBytes: Number, maxFileBytes: Number,
    oneText: String, otherText: String, kilobytesText: String, megabytesText: String,
    tooManyFilesText: String, notJsonText: String, fileTooLargeText: String, totalTooLargeText: String
  }

  refresh() {
    const files = Array.from(this.inputTarget.files)
    this.listTarget.replaceChildren(...files.map((file) => this.line(file)))
    this.listTarget.hidden = files.length === 0
    const total = files.reduce((sum, file) => sum + file.size, 0)
    this.countTarget.textContent = files.length === 0 ? "" : this.countText(files.length, total)
    this.showError(this.overflow(files, total))
  }

  // Un seul message à la fois, dans l'ordre de la règle du serveur.
  overflow(files, total) {
    if (files.length > this.maxFilesValue) return this.fill(this.tooManyFilesTextValue, { count: files.length, max: this.maxFilesValue })
    const notJson = files.find((file) => !/\.json$/i.test(file.name))
    if (notJson) return this.fill(this.notJsonTextValue, { name: notJson.name })
    const tooLarge = files.find((file) => file.size > this.maxFileBytesValue)
    if (tooLarge) return this.fill(this.fileTooLargeTextValue, { name: tooLarge.name, max: this.maxFileBytesValue / MEGABYTE })
    if (total > this.maxTotalBytesValue) return this.fill(this.totalTooLargeTextValue, { size: this.size(total), max: this.maxTotalBytesValue / MEGABYTE })
    return null
  }

  showError(message) {
    this.errorTarget.hidden = message === null
    this.messageTarget.textContent = message || ""
    if (message) this.inputTarget.setAttribute("aria-invalid", "true")
    else this.inputTarget.removeAttribute("aria-invalid")
    const submit = document.querySelector(`button[type="submit"][form="${this.element.id}"]`)
    if (submit) submit.disabled = message !== null
  }

  line(file) {
    const item = document.createElement("li")
    item.className = "flex items-baseline justify-between gap-3 px-3 py-1.5"
    const name = document.createElement("span")
    name.className = "truncate text-ink"
    name.textContent = file.name
    name.title = file.name
    const size = document.createElement("span")
    size.className = "shrink-0 tabular-nums text-mute"
    size.textContent = this.size(file.size)
    item.append(name, size)
    return item
  }

  countText(count, total) {
    return this.fill(count === 1 ? this.oneTextValue : this.otherTextValue, { count, size: this.size(total) })
  }

  // Ko arrondis sous 1 Mo, Mo à une décimale au-delà, avec la virgule décimale.
  size(bytes) {
    if (bytes < MEGABYTE) return this.fill(this.kilobytesTextValue, { size: Math.max(1, Math.round(bytes / KILOBYTE)) })
    return this.fill(this.megabytesTextValue, { size: (bytes / MEGABYTE).toFixed(1).replace(".", ",") })
  }

  fill(template, values) {
    return template.replace(/%\{(\w+)\}/g, (match, key) => (key in values ? String(values[key]) : match))
  }
}
