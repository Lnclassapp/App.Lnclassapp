# 🔌 INFRA · Orm::LevelSeries
# Rôle : table level_series, séries ouvertes à un niveau
# ADR  : 0034
module Orm
  class LevelSeries < ApplicationRecord
    self.table_name = "level_series"

    belongs_to :level, class_name: "Orm::Level", inverse_of: :level_series
    belongs_to :series, class_name: "Orm::Series", inverse_of: :level_series
  end
end
