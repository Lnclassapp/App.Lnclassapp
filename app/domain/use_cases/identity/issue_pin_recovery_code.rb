# 🧠 DOMAINE · UseCases::Identity::IssuePinRecoveryCode
# Rôle : l'enseignant ou l'équipe émet un code de récupération du PIN ; seule l'empreinte est gardée, le code en clair sort une fois
# ADR  : 0026, 0028, 0032, 0050 · UDR : 0020
module UseCases
  module Identity
    class IssuePinRecoveryCode
      Issued = Data.define(:user, :code, :expires_at)

      def initialize(users:, memberships:, teachings:, pin_recoveries:, audit_log:, transaction:, policy:, digest_key:, clock:)
        @users = users
        @memberships = memberships
        @teachings = teachings
        @pin_recoveries = pin_recoveries
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @digest_key = digest_key
        @clock = clock
      end

      # Émettre un code révoque le précédent (PinRecoveryRepositoryPort#issue). → success(Issued) | :forbidden | :not_found
      def call(actor:, target_public_id:)
        target = @users.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil?

        allowed = @policy.call(actor:, target:, teaches_target: teaches?(actor, target))
        return allowed if allowed.failure?

        @transaction.call { issue(actor, target, Entities::Identity::PinRecoveryCode.generate, @clock.now) }
      end

      private

      # Fait de la policy : l'élève est dans sa classe principale, active, que l'enseignant a déclarée.
      def teaches?(actor, target)
        return false unless actor&.teacher? && target.student?

        membership = @memberships.primary_for(student_id: target.id)
        return false unless membership&.classroom_active?

        @teachings.classroom_ids_for(teacher_id: actor.user_id).include?(membership.classroom_id)
      end

      def issue(actor, target, code, now)
        expires_at = now + Entities::Identity::PinRecoveryCode::TTL
        @pin_recoveries.issue(user_id: target.id, issued_by_id: actor.user_id, expires_at:, at: now,
                              code_digest: Entities::Identity::SecretDigest.hmac(code, key: @digest_key))
        @audit_log.record(action: "pin.recovery_code_issued", actor_id: actor.user_id, at: now, subject_type: "User",
                          subject_id: target.id)
        Shared::Result.success(Issued.new(user: target, code:, expires_at:))
      end
    end
  end
end
