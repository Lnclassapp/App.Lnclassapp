// ⚡ FRONT · rich_text_editor_controller — éditeur riche (Trix) des cours, des fiches et du blog
// Rôle : charge Trix à la demande, hors du bundle commun ; refuse tout fichier ; images pour le blog seul, sur valeur `attachments`
// ADR  : 0047, 0049, 0051, 0073 · UDR : 0014, 0016, 0065 · usage : stylesheet_link_tag("trix") ; data-rich-text-editor-lang-value + rich_textarea
import { Controller } from "@hotwired/stimulus"

// Without the attachments value (courses, sheets) the editor accepts no attachment: nothing reaches the bucket from it,
// there is no direct upload and @rails/actiontext is not loaded. The blog turns images on (UDR-0065 §3.7): they are
// shrunk by lib/image_upload, sent one by one to the team endpoint, never to Active Storage. The toolbar's file button
// stays hidden by CSS for everyone.
const refuseFile = (event) => event.preventDefault()
const dropAttachment = (event) => event.attachment.remove()

const fill = (template, values) => template.replace(/%\{(\w+)\}/g, (token, key) => values[key] ?? token)

// Trix builds its toolbar in English as soon as it is defined. The French texts go into Trix.config.lang for the
// next toolbars, and replace the English ones already on the page (title, text, placeholder, aria-label, value).
const TRANSLATED = ["title", "placeholder", "aria-label", "value"]
function translate(lang, texts, root) {
  const french = new Map(Object.entries(texts).map(([key, text]) => [lang[key], text]))
  Object.assign(lang, texts)
  root.querySelectorAll("[data-trix-button-group] button, [data-trix-dialogs] input").forEach((node) => {
    TRANSLATED.forEach((name) => french.has(node.getAttribute(name)) && node.setAttribute(name, french.get(node.getAttribute(name))))
    if (node.tagName === "BUTTON" && french.has(node.textContent)) node.textContent = french.get(node.textContent)
  })
}

export default class extends Controller {
  static targets = ["pickButton", "fileInput", "errors", "errorTemplate", "status"]
  static values = {
    lang: Object,
    attachments: { type: Boolean, default: false },
    uploadUrl: String,
    accept: Array,
    maxBytes: Number,
    maxSide: Number,
    maxCount: Number,
    messages: Object
  }

  async connect() {
    this.images = this.attachmentsValue && this.uploadUrlValue !== ""
    this.listeners = this.images
      ? { "trix-file-accept": this.accept, "trix-attachment-add": this.attachmentAdded, "trix-attachment-remove": this.attachmentRemoved }
      : { "trix-file-accept": refuseFile, "trix-attachment-add": dropAttachment }
    Object.entries(this.listeners).forEach(([type, listener]) => this.element.addEventListener(type, listener))
    if (this.images) this.listenForImages()

    const { default: Trix } = await import("trix")
    translate(Trix.config.lang, this.langValue, this.element)
    if (!this.images) return

    // Under an image, only its caption: neither the file name nor its size in English units (« 23.4 KB »).
    Trix.config.attachments.preview.caption = { name: false, size: false }
    this.pickButtonTarget.hidden = false
  }

  disconnect() {
    Object.entries(this.listeners).forEach(([type, listener]) => this.element.removeEventListener(type, listener))
    this.form?.removeEventListener("submit", this.hold)
  }

  listenForImages() {
    this.pending = new Set()
    this.queue = Promise.resolve()
    this.shrunk = new WeakSet()
    this.names = new WeakMap()
    this.form = this.element.closest("form")
    this.form?.addEventListener("submit", this.hold)
  }

  get editor() {
    return this.element.querySelector("trix-editor").editor
  }

  pickImages() {
    this.fileInputTarget.click()
  }

  insertPicked() {
    const files = [...this.fileInputTarget.files]
    this.fileInputTarget.value = ""
    this.insertFiles(files)
  }

  // A file already shrunk here goes in. Any other one (drop, paste) is refused to Trix, then shrunk and inserted again.
  // The files of one drop arrive one event each: they are gathered into one batch.
  accept = (event) => {
    if (this.shrunk.has(event.file)) return

    event.preventDefault()
    if (!this.dropped) {
      this.dropped = []
      queueMicrotask(() => {
        const files = this.dropped
        this.dropped = null
        this.insertFiles(files)
      })
    }
    this.dropped.push(event.file)
  }

  // The refusals of the previous batch are cleared; each file is checked, shrunk, then inserted at the cursor, in order.
  insertFiles(files) {
    if (files.length === 0) return

    this.errorsTarget.replaceChildren()
    this.errorsTarget.hidden = true
    this.track(this.prepare(files))
  }

  async prepare(files) {
    const { prepareImage } = await this.module().catch(() => ({}))
    for (const file of files) {
      try {
        if (!prepareImage) throw new Error("image_upload")
        const full = this.editor.getDocument().getAttachments().length >= this.maxCountValue
        const ready = await prepareImage(file, { accept: this.acceptValue, maxSide: this.maxSideValue, maxBytes: this.maxBytesValue, full })
        this.shrunk.add(ready)
        this.names.set(ready, file.name)
        this.editor.insertFile(ready)
      } catch (error) {
        this.refuse(file.name, error)
      }
    }
  }

  // With a sgid, an image of the article (load, undo); with a file, an image to send; neither, an image pasted from a
  // web page, hosted elsewhere: removed (ADR-0049).
  attachmentAdded = (event) => {
    const { attachment } = event
    const sgid = attachment.getAttribute("sgid")
    if (sgid) return this.dispatch("attached", { detail: { sgid } })
    if (attachment.file) return this.track(this.upload(attachment))

    attachment.remove()
    const name = attachment.getFilename() || (attachment.getURL() || "").split(/[/?#]/).filter(Boolean).pop() || ""
    this.refuse(name, { reason: "web_image" })
  }

  attachmentRemoved = (event) => {
    const sgid = event.attachment.getAttribute("sgid")
    if (sgid) this.dispatch("removed", { detail: { sgid } })
  }

  // One upload at a time; Trix draws its progress bar from setUploadProgress. A refused or failed image leaves the text.
  async upload(attachment) {
    const { file } = attachment
    const name = this.names.get(file) || file.name
    try {
      const { uploadImage } = await this.module()
      const sent = this.queue.then(() => {
        this.statusTarget.textContent = this.messagesValue.uploading
        return uploadImage(file, { url: this.uploadUrlValue, onProgress: (percent) => attachment.setUploadProgress(percent) })
      })
      this.queue = sent.catch(() => {})
      const image = await sent
      // Removed from the text during its upload: the image stays unattached, and the server purges it.
      if (!this.inText(attachment)) return

      attachment.setAttributes({ sgid: image.sgid, url: image.url, width: image.width, height: image.height })
      this.dispatch("uploaded", { detail: { publicId: image.public_id, sgid: image.sgid, url: image.url } })
    } catch (error) {
      if (this.inText(attachment)) attachment.remove()
      this.statusTarget.textContent = ""
      this.refuse(name, error)
    }
  }

  inText(attachment) {
    return Boolean(this.editor.getDocument().getAttachmentById(attachment.id))
  }

  refuse(name, { reason, detail } = {}) {
    const messages = this.messagesValue
    const line = this.errorTemplateTarget.content.firstElementChild.cloneNode(true)
    line.querySelector("span").textContent = fill(messages.refused, { name, reason: detail || messages[reason] || messages.failed })
    this.errorsTarget.append(line)
    this.errorsTarget.hidden = false
  }

  // The editor is busy while an image is being shrunk or sent.
  track(work) {
    this.pending.add(work)
    this.element.setAttribute("aria-busy", "true")
    work.finally(() => {
      this.pending.delete(work)
      if (this.pending.size === 0) this.element.removeAttribute("aria-busy")
    })
  }

  // « Enregistrer » during an upload: the article is saved once every upload is over, sent or refused.
  hold = (event) => {
    if (this.pending.size === 0) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.statusTarget.textContent = this.messagesValue.waiting
    const { submitter } = event
    Promise.allSettled([...this.pending]).then(() => this.form.requestSubmit(submitter))
  }

  module() {
    return import("../lib/image_upload")
  }
}
