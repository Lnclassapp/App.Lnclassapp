# 🔌 INFRA · Orm::CourseSheet
# Rôle : table course_sheets, la fiche de cours d'une leçon (document de blocs en jsonb, un par leçon)
# ADR  : 0110-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318)
module Orm
  class CourseSheet < ApplicationRecord
    self.table_name = "course_sheets"

    belongs_to :course, class_name: "Orm::Course"
  end
end
