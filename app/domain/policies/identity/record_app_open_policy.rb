# 🧠 DOMAINE · Policies::Identity::RecordAppOpenPolicy
# Rôle : seule l'ouverture de l'app installée par un élève ou un enseignant est datée ; le pilotage ne compte que ces deux rôles
# ADR  : 0028, 0082 (§4.3, §4.4)
module Policies
  module Identity
    class RecordAppOpenPolicy
      # Le use case n'agit que sur le compte de l'acteur (actor.user_id) : il n'y a pas de cible à comparer. Minimisation :
      # la direction et l'équipe, que le pilotage ne compte pas, ne laissent aucune trace d'usage.
      def call(actor:)
        return Shared::Result.success if actor&.student? || actor&.teacher?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
