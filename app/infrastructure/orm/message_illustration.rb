# 🔌 INFRA · Orm::MessageIllustration
# Rôle : table message_illustrations, les dessins de l'équipe pour les annonces, gardés en formes reconstruites (jsonb)
# ADR  : 0029, 0081
module Orm
  class MessageIllustration < ApplicationRecord
    include HasPublicId

    self.table_name = "message_illustrations"

    belongs_to :created_by, class_name: "Orm::User"
  end
end
