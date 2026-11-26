# 🔌 INFRA · Orm::Communication::PushApprovalRecipient
# Rôle : table push_approval_recipients : un couple élève × objet figé à la validation ; supprimé avec l'élève ou avec sa validation
# ADR  : XXXX envois de notifications (§4.1)
module Orm
  module Communication
    class PushApprovalRecipient < ApplicationRecord
      self.table_name = "push_approval_recipients"

      belongs_to :push_approval, class_name: "Orm::Communication::PushApproval"
      belongs_to :user, class_name: "Orm::User"

      validates :object_key, presence: true
    end
  end
end
