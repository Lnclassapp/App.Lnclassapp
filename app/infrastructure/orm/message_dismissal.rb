# 🔌 INFRA · Orm::MessageDismissal
# Rôle : table message_dismissals, une annonce masquée par un élève, sur tous ses appareils ; unique par compte
# ADR  : 0045, 0069
module Orm
  class MessageDismissal < ApplicationRecord
    self.table_name = "message_dismissals"

    belongs_to :message, class_name: "Orm::Message"
    belongs_to :user, class_name: "Orm::User"
  end
end
