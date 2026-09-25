# 🔌 INFRA · Orm::Drena
# Rôle : table drenas, directions régionales, cibles des imports d'établissements par leur slug
# ADR  : 0029, 0034
module Orm
  class Drena < ApplicationRecord
    include HasPublicId
    include HasFrozenSlug

    self.table_name = "drenas"

    has_frozen_slug from: :name

    has_many :schools, class_name: "Orm::School", inverse_of: :drena, dependent: :restrict_with_error

    # public_id dans les URL ; le slug ne sert qu'aux imports.
    def to_param = public_id
  end
end
