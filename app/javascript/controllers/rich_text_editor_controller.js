// ⚡ FRONT · rich_text_editor_controller — éditeur riche (Trix + Action Text) des cours et des fiches
// Rôle : charge Trix et Action Text à la demande, hors du bundle commun ; la page d'édition pose le CSS « trix »
// ADR  : 0051 · usage : content_for :head, stylesheet_link_tag("trix") ; <div data-controller="rich-text-editor"> + rich_text_area
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async connect() {
    await import("trix")
    await import("@rails/actiontext")
  }
}
