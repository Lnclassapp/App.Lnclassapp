# 🌐 UI · Communication::ArticleFormHelper — éditeur du blog dans la modale de l'équipe
# Rôle : données de #article_editor (mode images, plafonds, messages) lues par rich-text-editor ; texte au format de Trix
# ADR  : 0051, 0074 · UDR : 0067
module Communication
  module ArticleFormHelper
    IMAGE = Entities::Communication::ArticleImage
    # Jetons remplacés ici ; %{name}, %{reason} et %{number} le sont par le navigateur (UDR-0067 §3.4.3).
    SERVER_TOKENS = /%\{(max_bytes|max_count)\}/

    # → le hash data de #article_editor (UDR-0067 §3.4.4). Les plafonds viennent de ArticleImage, jamais d'un chiffre écrit.
    def article_editor_data(upload_url:)
      {
        "rich-text-editor-lang-value" => t("components.rich_text_editor.lang").to_json,
        "rich-text-editor-attachments-value" => true,
        "rich-text-editor-upload-url-value" => upload_url,
        "rich-text-editor-accept-value" => IMAGE::CONTENT_TYPES.to_json,
        "rich-text-editor-max-bytes-value" => IMAGE::MAX_BYTES,
        "rich-text-editor-max-side-value" => IMAGE::MAX_SIDE,
        "rich-text-editor-max-count-value" => IMAGE::MAX_PER_ARTICLE,
        "rich-text-editor-messages-value" => image_messages.to_json
      }
    end

    # Le texte enregistré (pièces jointes par sgid) ou envoyé (figures de Trix), au format que Trix charge : chaque
    # image y porte son adresse et ses dimensions (Orm::ArticleImage#to_rich_text_attributes).
    def article_editor_body(html) = ActionText::Content.new(html.to_s).to_trix_html

    private

    def image_messages
      caps = { "max_bytes" => number_to_human_size(IMAGE::MAX_BYTES), "max_count" => IMAGE::MAX_PER_ARTICLE.to_s }
      t("teams.articles.form.image_messages").transform_values { it.gsub(SERVER_TOKENS) { caps.fetch(Regexp.last_match(1)) } }
    end
  end
end
