# 🧠 DOMAINE · UseCases::Identity::CompleteTeacherOnboarding
# Rôle : l'enseignant termine sa configuration ; exige au moins une classe déclarée ; l'état est enregistré, jamais déduit
# ADR  : 0026, 0028, 0030 · UDR : 0025
module UseCases
  module Identity
    class CompleteTeacherOnboarding
      def initialize(profiles:, teachings:, policy:, clock:)
        @profiles = profiles
        @teachings = teachings
        @policy = policy
        @clock = clock
      end

      # → Result | :forbidden | :invalid (aucune classe déclarée) ; idempotent
      def call(actor:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: { base: [ :no_classroom ] }) if @teachings.classroom_ids_for(teacher_id: actor.user_id).empty?

        @profiles.complete_onboarding(user_id: actor.user_id, at: @clock.now)
        Shared::Result.success
      end
    end
  end
end
