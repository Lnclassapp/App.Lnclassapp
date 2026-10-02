# 🔌 INFRA · Orm::ClassroomAssignment
# Rôle : table classroom_assignments ; assignable_type et assignable_id sont de simples colonnes
# ADR  : 0029, 0048
module Orm
  class ClassroomAssignment < ApplicationRecord
    include HasPublicId

    self.table_name = "classroom_assignments"

    belongs_to :classroom, class_name: "Orm::Classroom", inverse_of: :classroom_assignments
    belongs_to :assigned_by, class_name: "Orm::User"
    belongs_to :archived_by, class_name: "Orm::User", optional: true
  end
end
