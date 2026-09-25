# 🔌 INFRA · Orm::Course
# Rôle : table courses, cours du catalogue (brouillon, publié, archivé), adressés par slug
# ADR  : 0029, 0035
module Orm
  class Course < ApplicationRecord
    include HasFrozenSlug

    self.table_name = "courses"

    has_frozen_slug from: :name

    belongs_to :level, class_name: "Orm::Level"
    belongs_to :material, class_name: "Orm::Material", inverse_of: :courses
    belongs_to :series, class_name: "Orm::Series", optional: true
    belongs_to :author, class_name: "Orm::User"

    has_rich_text :content

    has_many :essentials, class_name: "Orm::Essential", inverse_of: :course, dependent: :restrict_with_error
  end
end
