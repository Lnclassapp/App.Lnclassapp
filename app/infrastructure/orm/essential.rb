# 🔌 INFRA · Orm::Essential
# Rôle : table essentials, fiches essentielles d'un cours ; slug tiré du cours puis de la fiche
# ADR  : 0029, 0035, 0089
module Orm
  class Essential < ApplicationRecord
    include HasFrozenSlug

    self.table_name = "essentials"

    has_frozen_slug from: -> { "#{course&.name} #{name}" }

    belongs_to :course, class_name: "Orm::Course", inverse_of: :essentials
    belongs_to :author, class_name: "Orm::User"

    has_rich_text :content
    # Les images que cite le texte (FK RESTRICT : une fiche ne part pas avec ses images, ADR-0036).
    has_many :images, class_name: "Orm::EssentialImage", inverse_of: :essential, dependent: nil

    has_many :exercises, class_name: "Orm::Exercise", inverse_of: :essential, dependent: :restrict_with_error
  end
end
