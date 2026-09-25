# 🧠 DOMAINE · UseCases::Identity::BeginSecondFactorEnrollment
# Rôle : ouvre l'activation TOTP d'un compte team non confirmé (secret et URI du QR code)
# ADR  : 0028, 0031
module UseCases
  module Identity
    class BeginSecondFactorEnrollment
      def initialize(users:, second_factors:, policy:)
        @users = users
        @second_factors = second_factors
        @policy = policy
      end

      # session : Entities::Identity::SessionState. → success(SecondFactorRepositoryPort::Enrollment) | :forbidden
      def call(session:)
        allowed = @policy.call(actor: nil, session:, step: :enroll)
        return allowed if allowed.failure?

        label = @users.find(id: session.user_id).contact
        Shared::Result.success(@second_factors.begin_enrollment(user_id: session.user_id, label:))
      end
    end
  end
end
