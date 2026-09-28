# 🧠 DOMAINE · Policies::Identity::InviteColleaguePolicy
# Rôle : seul un enseignant dont l'établissement principal est actif invite un collègue
# ADR  : 0028, 0063
module Policies
  module Identity
    class InviteColleaguePolicy
      # school : Entities::School::School, l'école principale de l'acteur (nil sans école).
      def call(actor:, school:)
        return Shared::Result.success if actor&.teacher? && school&.active? && school.id == actor.school_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
