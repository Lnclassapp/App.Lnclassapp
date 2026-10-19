# 🔌 INFRA · Orm::School
# Rôle : table schools, établissements (public, privé, mixte) et leurs classes ; filtres de la liste partagés (list_filtered)
# ADR  : 0029, 0030, 0083, 0096
module Orm
  class School < ApplicationRecord
    include HasPublicId

    self.table_name = "schools"

    # La recherche ignore casse et accents sans extension PostgreSQL : les deux côtés passent par la même table.
    ACCENTED = "àâäçéèêëîïôöùûüÿÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ".freeze
    PLAIN = "aaaceeeeiioouuuyaaaceeeeiioouuuy".freeze
    # IE-21 (ADR-0083 §4.5) : nom ou sigle seulement.
    SEARCHED = %w[schools.name schools.sigle].map { "translate(lower(#{it}), '#{ACCENTED}', '#{PLAIN}') LIKE :pattern" }
                                              .join(" OR ").freeze

    belongs_to :drena, class_name: "Orm::Drena", inverse_of: :schools

    has_many :classrooms, class_name: "Orm::Classroom", inverse_of: :school, dependent: :restrict_with_error
    has_many :teacher_schools, class_name: "Orm::TeacherSchool", inverse_of: :school, dependent: :restrict_with_error

    # ADR-0096 §4.5 : une seule définition des filtres de la liste « Établissements », lue par la liste, la modale et les
    # régénérations de masse. Une valeur hors de sa liste fermée est ignorée, comme à l'écran.
    scope :list_filtered, lambda { |drena: nil, school_type: nil, cycle: nil, status: nil, search: nil|
      scope = joins(:drena)
      scope = scope.where(drenas: { public_id: drena }) if drena.present?
      scope = scope.where(school_type:) if Entities::School::School::SCHOOL_TYPES.include?(school_type)
      scope = scope.where(cycle:) if Entities::School::School::CYCLES.include?(cycle)
      scope = scope.where(status:) if Entities::School::School::STATUSES.include?(status)
      term = ActiveSupport::Inflector.transliterate(search.to_s.squish).downcase
      term.empty? ? scope : scope.where(SEARCHED, pattern: "%#{sanitize_sql_like(term)}%")
    }

    # Sélection d'une régénération de masse (Dtos::School::SchoolSelection) : un établissement, ou les filtres de la liste.
    scope :regeneration_selection, lambda { |selection|
      selection.school ? joins(:drena).where(public_id: selection.school) : list_filtered(**selection.filters)
    }
  end
end
