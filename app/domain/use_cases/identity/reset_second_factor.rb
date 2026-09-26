# 🧠 DOMAINE · UseCases::Identity::ResetSecondFactor
# Rôle : un membre de l'équipe réinitialise le second facteur d'un autre ; le membre est déconnecté partout et réenrôle son TOTP
# ADR  : 0026, 0028, 0031, 0050 · UDR : 0020
module UseCases
  module Identity
    class ResetSecondFactor
      def initialize(users:, second_factors:, sessions:, audit_log:, transaction:, policy:, clock:)
        @users = users
        @second_factors = second_factors
        @sessions = sessions
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → success(Entities::Identity::User) | :forbidden (son propre compte, un compte hors équipe) | :not_found
      def call(actor:, target_public_id:)
        target = @users.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil?

        allowed = @policy.call(actor:, target:)
        return allowed if allowed.failure?

        @transaction.call { reset(actor, target, @clock.now) }
      end

      private

      def reset(actor, target, now)
        @second_factors.reset(user_id: target.id)
        @sessions.destroy_all_for(user_id: target.id)
        @audit_log.record(action: "totp.reset", actor_id: actor.user_id, at: now, subject_type: "User", subject_id: target.id)
        Shared::Result.success(target)
      end
    end
  end
end
