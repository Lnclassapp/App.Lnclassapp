// ⚡ FRONT · communication/image_alts_controller — panneau « Images du texte » : une ligne par image, dans l'ordre du texte
// Rôle : ligne ajoutée à l'envoi d'une image, cachée quand elle quitte le texte, renumérotée ; badge « À compléter » ; Entrée → éditeur
// ADR  : 0073 · UDR : 0065 (§3.4.2) · écoute les événements rich-text-editor:uploaded|attached|removed et trix-change
import { Controller } from "@hotwired/stimulus"

const TOKENS = /__(PUBLIC_ID|SGID|URL|NUMBER)__/g
const escapeHTML = (text) => String(text).replace(/[&<>"']/g, (character) => `&#${character.charCodeAt(0)};`)

export default class extends Controller {
  static targets = ["panel", "total", "list", "rowTemplate", "row"]

  // The focus does not move: the author keeps writing; the row carries its « À compléter » badge (WCAG 3.2.2).
  add({ detail: { publicId, sgid, url } }) {
    const values = { PUBLIC_ID: publicId, SGID: sgid, URL: url, NUMBER: "" }
    this.listTarget.insertAdjacentHTML("beforeend", this.rowTemplateTarget.innerHTML.replace(TOKENS, (token, key) => escapeHTML(values[key])))
    this.renumber()
    const number = this.rowFor(sgid).querySelector("[data-number]").textContent
    const messages = JSON.parse(this.element.getAttribute("data-rich-text-editor-messages-value"))
    this.element.querySelector("[data-rich-text-editor-target~=status]").textContent = messages.uploaded.replace("%{number}", number)
  }

  // An image taken out of the text: its row is hidden and its field disabled (not sent), its text kept for an undo.
  remove({ detail: { sgid } }) {
    this.toggle(sgid, false)
  }

  restore({ detail: { sgid } }) {
    this.toggle(sgid, true)
  }

  // Visible rows in the order of the text's attachments, numbered from 1; the panel is hidden without any.
  renumber() {
    const order = this.attachmentSgids()
    const rank = (row) => (order.includes(row.dataset.sgid) ? order.indexOf(row.dataset.sgid) : order.length)
    const visible = this.rowTargets.filter((row) => !row.hidden).sort((first, second) => rank(first) - rank(second))
    const rows = [...visible, ...this.rowTargets.filter((row) => row.hidden)]
    if (rows.some((row, index) => this.listTarget.children[index] !== row)) this.listTarget.append(...rows)

    visible.forEach((row, index) => (row.querySelector("[data-number]").textContent = index + 1))
    this.totalTarget.textContent = `(${visible.length})`
    this.panelTarget.hidden = visible.length === 0
  }

  mark({ target }) {
    target.closest("li").querySelector("[data-communication--image-alts-target~=missing]").hidden = target.value.trim() !== ""
  }

  // Enter never submits the form from this field: it goes back to the text, right after the image of the row.
  backToEditor(event) {
    event.preventDefault()
    const element = this.element.querySelector("trix-editor")
    const { editor } = element
    const attachment = editor.getDocument().getAttachments().find((each) => each.getAttribute("sgid") === event.target.closest("li").dataset.sgid)
    element.focus()
    if (attachment) editor.setSelectedRange(editor.getDocument().getRangeOfAttachment(attachment)[1])
  }

  toggle(sgid, shown) {
    const row = this.rowFor(sgid)
    if (!row) return

    row.hidden = !shown
    row.querySelector("input").disabled = !shown
    this.renumber()
  }

  rowFor(sgid) {
    return this.rowTargets.find((row) => row.dataset.sgid === sgid)
  }

  // Before Trix is loaded, the server's order holds.
  attachmentSgids() {
    const editor = this.element.querySelector("trix-editor")?.editor
    return editor ? editor.getDocument().getAttachments().map((attachment) => attachment.getAttribute("sgid")) : []
  }
}
