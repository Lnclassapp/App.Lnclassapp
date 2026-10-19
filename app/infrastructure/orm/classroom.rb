# 🔌 INFRA · Orm::Classroom
# Rôle : table classrooms ; aucune association polymorphe vers les ressources assignées ; classes d'une régénération de masse
# ADR  : 0029, 0036, 0041, 0096
module Orm
  class Classroom < ApplicationRecord
    include HasPublicId

    self.table_name = "classrooms"

    belongs_to :school, class_name: "Orm::School", inverse_of: :classrooms
    belongs_to :level, class_name: "Orm::Level"
    belongs_to :series, class_name: "Orm::Series", optional: true

    has_many :classroom_students, class_name: "Orm::ClassroomStudent", inverse_of: :classroom, dependent: :restrict_with_error
    has_many :teacher_classrooms, class_name: "Orm::TeacherClassroom", inverse_of: :classroom, dependent: :restrict_with_error
    has_many :classroom_assignments, class_name: "Orm::ClassroomAssignment", inverse_of: :classroom,
                                     dependent: :restrict_with_error

    # ADR-0096 §4.5 : les classes actives des établissements d'une sélection (Dtos::School::SchoolSelection), d'une année
    # (nil : toutes) ; lu par la modale et par le repository, pour que le nombre confirmé soit celui du job.
    scope :link_regeneration, lambda { |selection, school_year|
      scope = where(status: "active", school_id: Orm::School.regeneration_selection(selection).select(:id))
      school_year ? scope.where(school_year:) : scope
    }
  end
end
