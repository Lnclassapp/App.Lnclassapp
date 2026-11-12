# 🧠 DOMAINE · UseCases::Crm::AssignOwner
# Rôle : l'équipe nomme le responsable d'une école parmi les membres assignables (admin, field), ou n'en nomme aucun ; journalisé
# ADR  : XXXX (contexte crm)
module UseCases
  module Crm
    class AssignOwner
      def initialize(accounts:, audit_log:, transaction:, policy:, assignable:, clock:)
        @accounts = accounts
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @assignable = assignable
        @clock = clock
      end

      # → Result(Account) | :forbidden | :invalid (errors: owner_id) ; le même responsable n'écrit rien
      def call(actor:, school_id:, owner_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        if owner_id && @assignable.call.none? { it.user_id == owner_id }
          return Shared::Result.failure(:invalid, errors: { owner_id: [ :invalid ] })
        end

        current = @accounts.find_by_school_id(school_id:) || Entities::Crm::Account.blank(school_id)
        return Shared::Result.success(current) if current.owner_id == owner_id

        @transaction.call { change(actor, current, owner_id) }
      end

      private

      def change(actor, current, owner_id)
        saved = @accounts.save(account: current.with(owner_id:))
        return saved if saved.failure?

        @audit_log.record(action: "crm.owner_changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: current.school_id, metadata: { from: current.owner_id, to: owner_id })
        saved
      end
    end
  end
end
