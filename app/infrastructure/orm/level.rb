# 🔌 INFRA · Orm::Level
# Rôle : table levels, niveaux ; le slug figé est le code du plan de génération des classes
# ADR  : 0029, 0030, 0034
module Orm
  class Level < ApplicationRecord
    include HasFrozenSlug

    self.table_name = "levels"

    has_frozen_slug from: :name

    has_many :level_series, class_name: "Orm::LevelSeries", inverse_of: :level, dependent: :restrict_with_error
    has_many :series, through: :level_series, class_name: "Orm::Series"
  end
end
