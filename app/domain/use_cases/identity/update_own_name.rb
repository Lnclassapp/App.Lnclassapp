# 🧠 DOMAINE · UseCases::Identity::UpdateOwnName
# Rôle : chacun corrige son nom et son prénom, aux limites de l'inscription ; chaque changement est tracé (ancien et nouveau)
# ADR  : 0026, 0028, 0037, 0055
module UseCases
  module Identity
    class UpdateOwnName
      def initialize(users:, audit_log:, transaction:, policy:, clock:)
        @users = users
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # user : Entities::Identity::User, le compte de l'acteur ; dto : Dtos::Identity::PersonNameInput.
      # → success | :forbidden | :invalid (erreurs du DTO)
      def call(actor:, user:, dto:, ip:)
        allowed = @policy.call(actor:, target: user)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        previous = { first_name: user.first_name, last_name: user.last_name }
        current = { first_name: dto.first_name, last_name: dto.last_name }
        # Rien ne change : aucune écriture, aucune trace.
        return Shared::Result.success if previous == current

        @transaction.call { store(user, previous, current, ip) }
      end

      private

      def store(user, previous, current, ip)
        @users.update_name(user_id: user.id, **current)
        @audit_log.record(action: "profile.name_changed", actor_id: user.id, at: @clock.now, subject_type: "User",
                          subject_id: user.id, metadata: { previous:, current: }, ip:)
        Shared::Result.success
      end
    end
  end
end
