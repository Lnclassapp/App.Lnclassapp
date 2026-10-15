# 🔌 INFRA · Orm::EssentialRead
# Rôle : table essential_reads, une ligne par fiche ouverte par un élève (première et dernière ouverture)
# ADR  : 0090 (§4.1)
module Orm
  class EssentialRead < ApplicationRecord
    self.table_name = "essential_reads"

    belongs_to :student, class_name: "Orm::User"
    belongs_to :essential, class_name: "Orm::Essential"
  end
end
