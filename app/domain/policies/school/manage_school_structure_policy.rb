# 🧠 DOMAINE · Policies::School::ManageSchoolStructurePolicy
# Rôle : « + », « − », archivage et code d'un établissement : l'équipe partout, la direction de rang « gestion » chez elle
# ADR  : 0028, 0057, 0059, 0071, 0088, 0092 (§4.3) · l'éducateur et la secrétaire (rang « vie scolaire ») : 403
module Policies
  module School
    class ManageSchoolStructurePolicy
      ACTIVE = "active".freeze

      def call(actor:, school:)
        return Shared::Result.failure(:forbidden) if actor.nil? || school.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.school_management? && actor.school_id == school.id && school.status == ACTIVE

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
