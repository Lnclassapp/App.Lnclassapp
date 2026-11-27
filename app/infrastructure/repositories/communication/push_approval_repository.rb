# 🔌 INFRA · Repositories::Communication::PushApprovalRepository
# Rôle : validations passées en base (push_approvals, push_approval_recipients) : lues par l'historique, purgées ; plus aucune n'est écrite
# ADR  : 0147 (§4.1, §4.2, amendement du 2026-11-27 II) · adaptateur de Ports::Communication::PushApprovalRepositoryPort
module Repositories
  module Communication
    class PushApprovalRepository
      include Ports::Communication::PushApprovalRepositoryPort

      def history(since:) = Orm::Communication::PushApproval.where(approved_at: since..).order(approved_at: :desc).map { to_entity(it) }

      def purge_before(before:)
        Orm::Communication::PushApproval.where(approved_at: ...before).delete_all
      end

      private

      def to_entity(row)
        Entities::Communication::PushApproval.new(id: row.id, on_date: row.on_date, motive: row.motive, approved_by_id: row.approved_by_id,
                                                  approved_at: row.approved_at, recipients_count: row.recipients_count)
      end
    end
  end
end
