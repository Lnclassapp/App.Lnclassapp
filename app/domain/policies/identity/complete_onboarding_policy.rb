# 🧠 DOMAINE · Policies::Identity::CompleteOnboardingPolicy
# Rôle : un enseignant termine son propre onboarding (classes déclarées) ; personne d'autre
# ADR  : 0028
module Policies
  module Identity
    class CompleteOnboardingPolicy
      # Le use case n'agit que sur le profil de l'acteur (actor.user_id) : il n'y a pas de cible à comparer.
      def call(actor:)
        return Shared::Result.success if actor && actor.teacher?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
