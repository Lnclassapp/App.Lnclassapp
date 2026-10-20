# 🧠 DOMAINE · Policies::Identity::InviteColleaguePolicy
# Rôle : seul un enseignant dont l'établissement courant est actif invite un collègue (lien de l'établissement, parrainage)
# ADR  : 0028, 0063, 0094 (§11)
module Policies
  module Identity
    class InviteColleaguePolicy
      # school : Entities::School::School, l'établissement courant de l'acteur (actor.school_id ; nil sans école).
      def call(actor:, school:)
        return Shared::Result.success if actor&.teacher? && school&.active? && school.id == actor.school_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
