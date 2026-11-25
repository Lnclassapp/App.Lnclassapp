# 🔌 INFRA · Repositories::Communication::PushApprovalRepository
# Rôle : validations du jour par l'équipe en base (push_approvals) et leurs destinataires figés (push_approval_recipients)
# ADR  : XXXX envois de notifications (§4.1, §4.2) · adaptateur de Ports::Communication::PushApprovalRepositoryPort
module Repositories
  module Communication
    class PushApprovalRepository
      include Ports::Communication::PushApprovalRepositoryPort

      def approved_keys(on_date:)
        Orm::Communication::PushApprovalRecipient.joins(:push_approval).where(push_approvals: { on_date: })
                                                 .pluck(:user_id, "push_approvals.motive", :object_key).to_set
      end

      def for_date(on_date:) = Orm::Communication::PushApproval.where(on_date:).order(:approved_at).map { to_entity(it) }

      # L'index unique (on_date, motive) départage deux validations simultanées : la perdante ne laisse aucune ligne.
      def create(on_date:, motive:, by:, at:, recipients:)
        pairs = recipients.uniq
        Orm::Communication::PushApproval.transaction(requires_new: true) do
          approval = Orm::Communication::PushApproval.create!(on_date:, motive:, approved_by_id: by, approved_at: at, recipients_count: pairs.size)
          rows = pairs.map { |user_id, object_key| { push_approval_id: approval.id, user_id:, object_key: } }
          Orm::Communication::PushApprovalRecipient.insert_all!(rows) if rows.any?
        end
        :created
      rescue ActiveRecord::RecordNotUnique
        :already_approved
      end

      def history(since:) = Orm::Communication::PushApproval.where(approved_at: since..).order(approved_at: :desc).map { to_entity(it) }

      def purge_before(before:)
        scope = Orm::Communication::PushApproval.where(approved_at: ...before)
        Orm::Communication::PushApprovalRecipient.where(push_approval_id: scope.select(:id)).delete_all
        scope.delete_all
      end

      private

      def to_entity(row)
        Entities::Communication::PushApproval.new(id: row.id, on_date: row.on_date, motive: row.motive, approved_by_id: row.approved_by_id,
                                                  approved_at: row.approved_at, recipients_count: row.recipients_count)
      end
    end
  end
end
