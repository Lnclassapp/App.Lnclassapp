// ⚡ FRONT · catalog/essential_image_slots_controller — emplacements « [[image: …]] » de l'import, dans l'éditeur de fiche
// Rôle : compteur et liste des emplacements restants ; une image insérée dans un emplacement le remplace et reprend sa description en texte de remplacement
// ADR  : 0089 · UDR : 0084 (§3.1) · écoute rich-text-editor:inserting|uploaded et trix-change, sur #essential_editor
import { Controller } from "@hotwired/stimulus"

// Same rule as Entities::Catalog::ImageSlot: the whole text of a paragraph, description of 1 to 150 characters.
const SLOT = /^\[\[image\x3a\s*([^\]\s][^\]]{0,149}?)\s*\]\]$/

const blockText = (block) => block.toString().replace(/\n$/, "").trim()

export default class extends Controller {
  static targets = ["panel", "badge", "list", "itemTemplate"]
  static values = { slotsLeft: Object, slot: String }

  connect() {
    this.descriptions = new WeakMap()
  }

  get editor() {
    return this.element.querySelector("trix-editor")?.editor
  }

  // Before Trix inserts the image: a cursor inside a slot paragraph selects the whole paragraph, so that the image takes
  // its place; the description is kept for the image's text alternative.
  claim({ detail: { file } }) {
    const editor = this.editor
    if (!editor) return

    const document = editor.getDocument()
    const [start] = editor.getSelectedRange()
    const { index } = document.locationFromPosition(start)
    const block = document.getBlockAtIndex(index)
    const match = block && blockText(block).match(SLOT)
    if (!match) return

    const from = document.positionFromLocation({ index, offset: 0 })
    editor.setSelectedRange([from, from + block.getLength() - 1])
    this.descriptions.set(file, match[1].trim())
  }

  // The image is sent and its row exists (communication--image-alts#add runs first): the slot's description fills it.
  describe({ detail: { publicId, file } }) {
    const description = file && this.descriptions.get(file)
    if (!description) return

    const field = this.element.querySelector(`[name$="[image_alts][${CSS.escape(publicId)}]"]`)
    if (!field || field.value.trim() !== "") return

    field.value = description
    field.dispatchEvent(new Event("input", { bubbles: true }))
  }

  // Slots still in the text, read in Trix's document at each change.
  refresh() {
    const editor = this.editor
    if (!editor) return

    const slots = editor.getDocument().getBlocks().map((block) => blockText(block).match(SLOT)).filter(Boolean).map((match) => match[1].trim())
    this.panelTarget.hidden = slots.length === 0
    const label = (slots.length === 1 ? this.slotsLeftValue.one : this.slotsLeftValue.other) || ""
    const badge = this.badgeTarget.firstElementChild || this.badgeTarget
    badge.textContent = label.replace("%{count}", slots.length)
    this.listTarget.replaceChildren(...slots.map((description) => {
      const item = this.itemTemplateTarget.content.firstElementChild.cloneNode(true)
      item.querySelector("span").textContent = this.slotValue.replace("%{description}", description)
      return item
    }))
  }
}
