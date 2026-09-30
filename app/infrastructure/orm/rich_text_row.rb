# 🔌 INFRA · Orm::RichTextRow
# Rôle : écriture en masse de la table action_text_rich_texts, body en texte brut, sans type Action Text
# ADR  : 0068
module Orm
  # Pour l'import seulement (ContentTreeWriter) : le corps y arrive déjà assaini et n'est pas converti par
  # ActionText::Content. Les formulaires et la lecture passent toujours par le modèle Action Text (has_rich_text).
  class RichTextRow < ApplicationRecord
    self.table_name = "action_text_rich_texts"
  end
end
