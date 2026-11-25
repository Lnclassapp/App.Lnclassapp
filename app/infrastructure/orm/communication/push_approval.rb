# 🔌 INFRA · Orm::Communication::PushApproval
# Rôle : table push_approvals : la validation d'un motif pour un jour d'Abidjan (unique par jour et motif), avec ses destinataires figés
# ADR  : XXXX envois de notifications (§4.1)
module Orm
  module Communication
    class PushApproval < ApplicationRecord
      self.table_name = "push_approvals"

      belongs_to :approved_by, class_name: "Orm::User"
      has_many :recipients, class_name: "Orm::Communication::PushApprovalRecipient", foreign_key: :push_approval_id,
                            inverse_of: :push_approval, dependent: :delete_all

      validates :on_date, :motive, :approved_at, presence: true
    end
  end
end
