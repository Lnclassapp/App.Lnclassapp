# 🔌 INFRA · Orm::Subject
# Rôle : table subjects, sujets de devoir d'une leçon (titre, notions mobilisées, ordre) ; ses exercices n'ont pas de notion
# ADR  : 0121
module Orm
  class Subject < ApplicationRecord
    self.table_name = "subjects"

    belongs_to :course, class_name: "Orm::Course", inverse_of: :subjects
    has_many :exercises, -> { order(:position) }, class_name: "Orm::Exercise", inverse_of: :subject, dependent: :restrict_with_error
  end
end
