# 🔌 INFRA · Orm::KnowledgeGap
# Rôle : table knowledge_gaps, lacune d'un élève sur une fiche, née et résolue à la clôture
# ADR  : 0029, 0043
module Orm
  class KnowledgeGap < ApplicationRecord
    include HasPublicId

    self.table_name = "knowledge_gaps"

    belongs_to :student, class_name: "Orm::User"
    belongs_to :essential, class_name: "Orm::Essential"
    belongs_to :source_session, class_name: "Orm::ExerciseSession"
    belongs_to :resolved_by_session, class_name: "Orm::ExerciseSession", optional: true
  end
end
