# 🔌 INFRA · Orm::Essential
# Rôle : table essentials, notions d'une leçon (fiche de révision en jsonb) ; slug tiré du cours puis de la notion
# ADR  : 0029, 0035, 0116
module Orm
  class Essential < ApplicationRecord
    include HasFrozenSlug

    self.table_name = "essentials"

    has_frozen_slug from: -> { "#{course&.name} #{name}" }

    belongs_to :course, class_name: "Orm::Course", inverse_of: :essentials
    belongs_to :author, class_name: "Orm::User"

    has_many :exercises, class_name: "Orm::Exercise", inverse_of: :essential, dependent: :restrict_with_error
  end
end
