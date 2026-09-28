# 🔌 INFRA · Orm::SchoolJoinRequest
# Rôle : table school_join_requests, demande d'un enseignant inscrit sans code, en attente d'une décision
# ADR  : 0029, 0063
module Orm
  class SchoolJoinRequest < ApplicationRecord
    include HasPublicId

    self.table_name = "school_join_requests"

    belongs_to :teacher, class_name: "Orm::User"
    belongs_to :school, class_name: "Orm::School"
    belongs_to :decided_by, class_name: "Orm::User", optional: true
  end
end
