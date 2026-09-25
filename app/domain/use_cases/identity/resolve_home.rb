# 🧠 DOMAINE · UseCases::Identity::ResolveHome
# Rôle : destination d'accueil d'un acteur connecté, sans boucle de redirection
# ADR  : 0030, 0040
module UseCases
  module Identity
    class ResolveHome
      def initialize(memberships:, teacher_profiles:)
        @memberships = memberships
        @teacher_profiles = teacher_profiles
      end

      # → success(Symbol ∈ Entities::Identity::HomeDestination::ALL)
      def call(actor:)
        return Shared::Result.failure(:forbidden) if actor.nil?

        membership = @memberships.primary_for(student_id: actor.user_id) if actor.student?
        onboarded = actor.teacher? && @teacher_profiles.find_by_user_id(user_id: actor.user_id)&.onboarded? || false
        Shared::Result.success(Entities::Identity::HomeDestination.for(actor:, primary_membership: membership, onboarded:))
      end
    end
  end
end
