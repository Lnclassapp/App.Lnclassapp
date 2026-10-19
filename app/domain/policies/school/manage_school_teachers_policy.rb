# 🧠 DOMAINE · Policies::School::ManageSchoolTeachersPolicy
# Rôle : retirer et réintégrer un enseignant : la direction de rang « gestion » de cet établissement actif, jamais l'équipe
# ADR  : 0028, 0071, 0092 (§4.3) · l'éducateur et la secrétaire (rang « vie scolaire ») : 403
module Policies
  module School
    class ManageSchoolTeachersPolicy
      ACTIVE = "active".freeze

      def call(actor:, school:)
        return Shared::Result.success if actor&.school_management? && school && actor.school_id == school.id && school.status == ACTIVE

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
