# 🧠 DOMAINE · UseCases::Crm::SetStage
# Rôle : l'équipe saisit l'étape d'une école (Prospect, Démo faite, Abonnée, Perdue) ; « Perdue » exige un motif ; journalisé
# ADR  : XXXX (contexte crm)
module UseCases
  module Crm
    class SetStage
      def initialize(accounts:, audit_log:, transaction:, policy:, clock:)
        @accounts = accounts
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Account) | :forbidden | :invalid (errors: stage, lost_reason) ; la même étape n'écrit rien
      def call(actor:, school_id:, stage:, lost_reason:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        lost_reason = lost_reason.to_s.presence
        errors = validate(stage:, lost_reason:)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        lost_reason = nil unless stage == "lost"
        current = @accounts.find_by_school_id(school_id:) || Entities::Crm::Account.blank(school_id)
        return Shared::Result.success(current) if current.stage == stage && current.lost_reason == lost_reason

        @transaction.call { change(actor, current, stage, lost_reason) }
      end

      private

      def validate(stage:, lost_reason:)
        errors = {}
        errors[:stage] = [ :inclusion ] unless Entities::Crm::Stage::TYPEABLE.include?(stage)
        if stage == "lost"
          errors[:lost_reason] = [ :blank ] if lost_reason.nil?
          errors[:lost_reason] = [ :inclusion ] if lost_reason && !Entities::Crm::Account::LOST_REASONS.include?(lost_reason)
        end
        errors
      end

      def change(actor, current, stage, lost_reason)
        at = @clock.now
        saved = @accounts.save(account: current.with(stage:, lost_reason:, stage_changed_at: at))
        return saved if saved.failure?

        @audit_log.record(action: "crm.stage_changed", actor_id: actor.user_id, at:, subject_type: "School", subject_id: current.school_id,
                          metadata: { from: current.stage, to: stage, lost_reason: })
        saved
      end
    end
  end
end
