# 🧠 DOMAINE · UseCases::Identity::BeginSecondFactorEnrollment
# Rôle : ouvre l'activation TOTP d'un compte team non confirmé (secret et URI du QR)
# ADR  : 0031
module UseCases
  module Identity
    class BeginSecondFactorEnrollment
      def initialize(users:, second_factors:)
        @users = users
        @second_factors = second_factors
      end

      # → success(Ports::Identity::SecondFactorRepositoryPort::Enrollment)
      def call(user_id:)
        user = @users.find(id: user_id)
        return Shared::Result.failure(:not_found) unless user
        return Shared::Result.failure(:conflict, errors: { base: [ :not_team ] }) unless user.team?
        return Shared::Result.failure(:conflict, errors: { base: [ :already_enrolled ] }) if @second_factors.state_for(user_id:)&.confirmed

        Shared::Result.success(@second_factors.begin_enrollment(user_id:, label: user.contact))
      end
    end
  end
end
