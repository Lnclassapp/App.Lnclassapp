# 🧠 DOMAINE · Policies::School::ManageSchoolTeachersPolicy
# Rôle : retirer et réintégrer un enseignant : la direction de cet établissement actif seulement, jamais l'équipe (grill 9)
# ADR  : 0028, 0071
module Policies
  module School
    class ManageSchoolTeachersPolicy
      ACTIVE = "active".freeze

      def call(actor:, school:)
        return Shared::Result.success if actor&.school_admin? && school && actor.school_id == school.id && school.status == ACTIVE

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
