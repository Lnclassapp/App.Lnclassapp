# 🌐 UI · Catalog::EssentialFormHelper — éditeur de fiche en mode images dans la modale de l'équipe
# Rôle : données de #essential_editor (mode images, plafonds d'un contenu, messages) lues par rich-text-editor ; texte au format de Trix
# ADR  : 0051, 0105 · UDR : 0129
module Catalog
  module EssentialFormHelper
    IMAGE = Entities::Shared::ContentImage
    # Jetons remplacés ici ; %{name}, %{reason} et %{number} le sont par le navigateur.
    SERVER_TOKENS = /%\{(max_bytes|max_count)\}/

    # → le hash data de #essential_editor. Les plafonds viennent de ContentImage, jamais d'un chiffre écrit (UDR-0129 §3.0).
    # squeeze : la qualité baisse jusqu'à 300 Ko ; field : le nom du fichier attendu par Teams::EssentialImagesController.
    def essential_editor_data(upload_url:)
      {
        "rich-text-editor-lang-value" => t("components.rich_text_editor.lang").to_json,
        "rich-text-editor-attachments-value" => true,
        "rich-text-editor-upload-url-value" => upload_url,
        "rich-text-editor-upload-field-value" => "essential_image[file]",
        "rich-text-editor-squeeze-value" => true,
        "rich-text-editor-accept-value" => IMAGE::CONTENT_TYPES.to_json,
        "rich-text-editor-max-bytes-value" => IMAGE::MAX_BYTES,
        "rich-text-editor-max-side-value" => IMAGE::MAX_SIDE,
        "rich-text-editor-max-count-value" => IMAGE::MAX_PER_ESSENTIAL,
        "rich-text-editor-messages-value" => essential_image_messages.to_json
      }
    end

    # Le texte enregistré (pièces jointes par sgid) ou envoyé (figures de Trix), au format que Trix charge.
    def essential_editor_content(html) = ActionText::Content.new(html.to_s).to_trix_html

    # Les emplacements annoncés par l'import et pas encore remplacés (UDR-0129 §3.1.1).
    def essential_image_slots(html) = Entities::Catalog::ImageSlot.scan(html)

    private

    def essential_image_messages
      caps = { "max_bytes" => number_to_human_size(IMAGE::MAX_BYTES), "max_count" => IMAGE::MAX_PER_ESSENTIAL.to_s }
      t("teams.essentials.form.image_messages").transform_values { it.gsub(SERVER_TOKENS) { caps.fetch(Regexp.last_match(1)) } }
    end
  end
end
