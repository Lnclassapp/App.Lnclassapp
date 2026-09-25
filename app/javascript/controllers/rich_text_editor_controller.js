// ⚡ FRONT · rich_text_editor_controller — éditeur riche (Trix) des cours et des fiches, sans pièce jointe
// Rôle : charge Trix à la demande, hors du bundle commun ; refuse tout fichier ; la page d'édition pose le CSS « trix »
// ADR  : 0047, 0049, 0051 · usage : stylesheet_link_tag("trix") ; <div data-controller="rich-text-editor" data-rich-text-editor-lang-value="<%= t("components.rich_text_editor.lang").to_json %>"> + rich_textarea
import { Controller } from "@hotwired/stimulus"

// V1 accepts no attachment: nothing reaches the bucket from the editor, so there is no
// direct upload and @rails/actiontext is not loaded. The file button is hidden by CSS.
const refuseFile = (event) => event.preventDefault()
const dropAttachment = (event) => event.attachment.remove()

// Trix builds its toolbar in English as soon as it is defined. The French texts go into Trix.config.lang for the
// next toolbars, and replace the English ones already on the page (title, text, placeholder, aria-label, value).
const TRANSLATED = ["title", "placeholder", "aria-label", "value"]
function translate(lang, texts, root) {
  const french = new Map(Object.entries(texts).map(([key, text]) => [lang[key], text]))
  Object.assign(lang, texts)
  root.querySelectorAll("trix-toolbar button, trix-toolbar input").forEach((node) => {
    TRANSLATED.forEach((name) => french.has(node.getAttribute(name)) && node.setAttribute(name, french.get(node.getAttribute(name))))
    if (node.tagName === "BUTTON" && french.has(node.textContent)) node.textContent = french.get(node.textContent)
  })
}

export default class extends Controller {
  static values = { lang: Object }

  async connect() {
    this.element.addEventListener("trix-file-accept", refuseFile)
    this.element.addEventListener("trix-attachment-add", dropAttachment)
    const { default: Trix } = await import("trix")
    translate(Trix.config.lang, this.langValue, this.element)
  }

  disconnect() {
    this.element.removeEventListener("trix-file-accept", refuseFile)
    this.element.removeEventListener("trix-attachment-add", dropAttachment)
  }
}
