# 🔌 INFRA · Orm::ImportReport
# Rôle : table import_reports, rapport persisté d'un import JSON ; fichiers sources sur le bucket
# ADR  : 0029, 0039, 0047, 0068
module Orm
  class ImportReport < ApplicationRecord
    include HasPublicId

    self.table_name = "import_reports"

    belongs_to :imported_by, class_name: "Orm::User"

    # ADR-0068 : un import de cours complets porte jusqu'à 50 fichiers ; les autres types, un seul.
    has_many_attached :sources
  end
end
