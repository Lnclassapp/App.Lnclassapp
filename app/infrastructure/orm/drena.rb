# 🔌 INFRA · Orm::Drena
# Rôle : table drenas, directions régionales, cibles des imports d'établissements par leur slug figé drena-…
# ADR  : 0029, 0034, 0066
module Orm
  class Drena < ApplicationRecord
    include HasPublicId
    include HasFrozenSlug

    self.table_name = "drenas"

    # Même règle qu'à l'import : « Bouaké 1 » → « drena-bouake-1 » (Entities::School::Drena.slug_for).
    has_frozen_slug from: -> { Entities::School::Drena.slug_for(name) }

    has_many :schools, class_name: "Orm::School", inverse_of: :drena, dependent: :restrict_with_error

    # public_id dans les URL ; le slug ne sert qu'aux imports.
    def to_param = public_id
  end
end
