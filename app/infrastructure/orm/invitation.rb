# 🔌 INFRA · Orm::Invitation
# Rôle : table invitations, invitations de l'équipe et de la direction (empreinte du jeton seulement)
# ADR  : 0038, 0044
module Orm
  class Invitation < ApplicationRecord
    self.table_name = "invitations"

    belongs_to :invited_by, class_name: "Orm::User", optional: true
    belongs_to :accepted_user, class_name: "Orm::User", optional: true
    belongs_to :school, class_name: "Orm::School", optional: true
  end
end
