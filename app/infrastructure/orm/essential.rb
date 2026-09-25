# 🔌 INFRA · Orm::Essential
# Rôle : table essentials, fiches essentielles d'un cours ; slug tiré du cours puis de la fiche
# ADR  : 0029, 0035
module Orm
  class Essential < ApplicationRecord
    include HasFrozenSlug

    self.table_name = "essentials"

    has_frozen_slug from: -> { "#{course&.name} #{name}" }

    belongs_to :course, class_name: "Orm::Course", inverse_of: :essentials
    belongs_to :author, class_name: "Orm::User"

    has_rich_text :content

    has_many :exercises, class_name: "Orm::Exercise", inverse_of: :essential, dependent: :restrict_with_error
  end
end
