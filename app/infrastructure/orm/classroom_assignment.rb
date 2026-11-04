# 🔌 INFRA · Orm::ClassroomAssignment
# Rôle : table classroom_assignments ; assignable_type et assignable_id sont de simples colonnes ; due_on, l'échéance figée ; batch_public_id, l'envoi d'origine
# ADR  : 0029, 0048, 0072, sujets-de-devoir (ajout du 2026-10-30)
module Orm
  class ClassroomAssignment < ApplicationRecord
    include HasPublicId

    self.table_name = "classroom_assignments"

    belongs_to :classroom, class_name: "Orm::Classroom", inverse_of: :classroom_assignments
    belongs_to :assigned_by, class_name: "Orm::User"
    belongs_to :archived_by, class_name: "Orm::User", optional: true
  end
end
