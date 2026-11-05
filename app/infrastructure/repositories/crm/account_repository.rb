# 🔌 INFRA · Repositories::Crm::AccountRepository
# Rôle : lit et écrit le suivi d'une école (table crm_accounts) ; une ligne par école, créée à la première écriture
# ADR  : XXXX (contexte crm)
module Repositories
  module Crm
    class AccountRepository
      include Ports::Crm::AccountRepositoryPort

      def find_by_school_id(school_id:)
        record = Orm::CrmAccount.find_by(school_id:)
        to_entity(record) if record
      end

      # « Perdue » sans motif : refusée aussi par la base (crm_accounts_lost_has_reason), ici avant l'écriture.
      def save(account:)
        return ::Shared::Result.failure(:invalid, errors: { lost_reason: [ :blank ] }) if account.stage == "lost" && account.lost_reason.nil?

        ::Shared::Result.success(to_entity(write(account)))
      rescue ActiveRecord::RecordNotUnique
        # Deux premières écritures simultanées : la perdante rend un conflit, la ligne gagnante reste.
        ::Shared::Result.failure(:conflict, errors: { base: [ :write_failed ] })
      end

      private

      def write(account)
        # Point de sauvegarde : un refus de la base n'abîme pas la transaction du use case.
        Orm::CrmAccount.transaction(requires_new: true) do
          record = Orm::CrmAccount.find_or_initialize_by(school_id: account.school_id)
          record.update!(stage: account.stage, owner_id: account.owner_id, lost_reason: account.lost_reason,
                         stage_changed_at: account.stage_changed_at || record.stage_changed_at || Time.current)
          record
        end
      end

      def to_entity(record)
        Entities::Crm::Account.new(school_id: record.school_id, stage: record.stage, owner_id: record.owner_id,
                                   lost_reason: record.lost_reason, stage_changed_at: record.stage_changed_at)
      end
    end
  end
end
