// ⚡ FRONT · voice-recorder — enregistre un compte rendu avec MediaRecorder (3 min au plus) et le met dans le champ fichier du formulaire
// Rôle : états prêt → enregistrement (minuteur mm:ss) → enregistré (aperçu local, « Envoyer » / « Recommencer ») ; micro refusé ou MediaRecorder absent : import d'un fichier
// ADR  : XXXX (modèles de langage, menace du compte rendu dicté : taille vérifiée ici pour le confort, le serveur recontrôle tout) · UDR : XXXX (assistants du suivi)
import { Controller } from "@hotwired/stimulus"

// Par ordre de préférence : Chrome et Firefox, Safari, puis ogg ; sinon le format que choisit le navigateur.
const MIME_TYPES = ["audio/webm;codecs=opus", "audio/mp4", "audio/ogg"]

export default class extends Controller {
  static targets = ["idle", "live", "done", "start", "stop", "timer", "preview", "send", "retry", "fallback", "error", "input"]
  static values = {
    maxSeconds: { type: Number, default: 180 },
    maxBytes: { type: Number, default: 10 * 1024 * 1024 },
    deniedMessage: String,
    tooBigMessage: String,
    unsupportedMessage: String,
  }

  connect() {
    this.elapsed = 0
    if (typeof MediaRecorder === "undefined" || !navigator.mediaDevices?.getUserMedia) {
      this.idleTarget.hidden = true
      this.fallbackTarget.hidden = false
    }
  }

  disconnect() {
    this.release()
    if (this.recorder?.state === "recording") {
      this.recorder.onstop = null
      this.recorder.stop()
    }
  }

  async start() {
    if (this.recorder?.state === "recording") return

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch {
      this.showError(this.deniedMessageValue)
      this.fallbackTarget.hidden = false
      return
    }

    const mimeType = MIME_TYPES.find((type) => MediaRecorder.isTypeSupported(type))
    this.chunks = []
    this.recorder = new MediaRecorder(this.stream, mimeType ? { mimeType } : undefined)
    this.recorder.ondataavailable = (event) => { if (event.data?.size) this.chunks.push(event.data) }
    this.recorder.onstop = () => this.finish()
    this.elapsed = 0
    this.timerTarget.textContent = this.format(0)
    this.errorTarget.hidden = true
    this.recorder.start()
    this.ticker = setInterval(() => this.tick(), 1000)
    this.show("live")
  }

  stop() {
    this.release()
    if (this.recorder?.state === "recording") this.recorder.stop()
  }

  retry() {
    this.forget()
    this.elapsed = 0
    this.timerTarget.textContent = this.format(0)
    this.errorTarget.hidden = true
    this.show("idle")
  }

  // Un fichier importé (repli) : type audio et taille contrôlés ici pour le confort ; le serveur revérifie par les octets.
  picked() {
    const file = this.inputTarget.files?.[0]
    if (!file) return

    if (file.size > this.maxBytesValue) return this.reject(this.tooBigMessageValue)
    if (!file.type.startsWith("audio/")) return this.reject(this.unsupportedMessageValue)

    this.errorTarget.hidden = true
    this.preview(file)
  }

  tick() {
    this.elapsed += 1
    this.timerTarget.textContent = this.format(this.elapsed)
    if (this.elapsed >= this.maxSecondsValue) this.stop()
  }

  finish() {
    const type = this.recorder.mimeType || MIME_TYPES[0]
    const blob = new Blob(this.chunks, { type })
    if (blob.size > this.maxBytesValue) {
      this.showError(this.tooBigMessageValue)
      return this.show("idle")
    }

    const extension = type.includes("mp4") ? "mp4" : type.includes("ogg") ? "ogg" : "webm"
    const file = new File([blob], `dictation.${extension}`, { type })
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files
    this.preview(file)
  }

  preview(file) {
    this.forgetPreview()
    this.previewUrl = URL.createObjectURL(file)
    this.previewTarget.src = this.previewUrl
    this.show("done")
  }

  reject(message) {
    this.inputTarget.value = ""
    this.showError(message)
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  show(state) {
    this.idleTarget.hidden = state !== "idle"
    this.liveTarget.hidden = state !== "live"
    this.doneTarget.hidden = state !== "done"
  }

  // Minuteur et micro : rien ne reste ouvert après l'arrêt.
  release() {
    clearInterval(this.ticker)
    this.stream?.getTracks().forEach((track) => track.stop())
  }

  forget() {
    this.forgetPreview()
    this.inputTarget.value = ""
  }

  forgetPreview() {
    if (this.previewUrl) URL.revokeObjectURL(this.previewUrl)
    this.previewUrl = null
  }

  format(seconds) {
    const pad = (value) => String(value).padStart(2, "0")
    return `${pad(Math.floor(seconds / 60))}:${pad(seconds % 60)}`
  }
}
