# 🔌 INFRA · Orm::Series
# Rôle : table series, séries du second cycle ; le slug figé est le code du plan de génération
# ADR  : 0029, 0030, 0034
module Orm
  class Series < ApplicationRecord
    include HasFrozenSlug

    self.table_name = "series"

    has_frozen_slug from: :name

    has_many :level_series, class_name: "Orm::LevelSeries", inverse_of: :series, dependent: :restrict_with_error
    has_many :levels, through: :level_series, class_name: "Orm::Level"
  end
end
