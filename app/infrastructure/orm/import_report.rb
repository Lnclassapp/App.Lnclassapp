# 🔌 INFRA · Orm::ImportReport
# Rôle : table import_reports, rapport persisté d'un import JSON ; fichier source sur le bucket
# ADR  : 0029, 0039, 0047
module Orm
  class ImportReport < ApplicationRecord
    include HasPublicId

    self.table_name = "import_reports"

    belongs_to :imported_by, class_name: "Orm::User"

    has_one_attached :source
  end
end
