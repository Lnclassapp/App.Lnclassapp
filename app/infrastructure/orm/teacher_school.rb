# 🔌 INFRA · Orm::TeacherSchool
# Rôle : table teacher_schools, établissements d'un enseignant (trois au plus, une seule école principale)
# ADR  : 0030, 0094
module Orm
  class TeacherSchool < ApplicationRecord
    self.table_name = "teacher_schools"

    belongs_to :teacher, class_name: "Orm::User"
    belongs_to :school, class_name: "Orm::School", inverse_of: :teacher_schools

    # ADR-0094 §4.2 : la ligne de l'établissement courant s'il y est encore rattaché, sinon la principale, en tête.
    # Lu par l'acteur et par la ligne de détail du shell et du profil : les trois disent le même établissement.
    scope :current_or_primary, lambda { |current_school_id|
      where("teacher_schools.primary OR teacher_schools.school_id = ?", current_school_id)
        .order(Arel.sql(sanitize_sql([ "teacher_schools.school_id = ? DESC NULLS LAST", current_school_id ])))
    }
  end
end
