# 🔌 INFRA · Orm::QuestionImage
# Rôle : l'image d'une question, vérifiée, sans métadonnées ; une au plus par question (index unique partiel)
# ADR  : 0029, 0060, 0105
module Orm
  class QuestionImage < ApplicationRecord
    include HasPublicId

    self.table_name = "question_images"

    belongs_to :question, class_name: "Orm::Question", optional: true, inverse_of: :image
    has_one_attached :file
  end
end
