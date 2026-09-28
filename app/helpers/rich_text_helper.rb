# 🌐 DELIVERY · RichTextHelper
# Rôle : attributs de l'éditeur riche sans téléversement : les routes Active Storage ne sont pas dessinées (ADR-0060)
# ADR  : 0060
module RichTextHelper
  # Action Text demande sinon rails_direct_uploads_url et rails_service_blob_url. L'éditeur refuse les pièces jointes
  # (rich_text_editor_controller) et @rails/actiontext n'est pas chargé : ces adresses ne servent à rien.
  def rich_text_without_uploads = { direct_upload_url: "", blob_url_template: "" }
end
