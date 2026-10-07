# 🧠 DOMAINE · Policies::School::ManageSchoolStructurePolicy
# Rôle : « + », « − » et code d'un établissement : l'équipe partout, la direction sur son seul établissement actif
# ADR  : 0028, 0057, 0059, 0071
module Policies
  module School
    class ManageSchoolStructurePolicy
      ACTIVE = "active".freeze

      def call(actor:, school:)
        return Shared::Result.failure(:forbidden) if actor.nil? || school.nil?
        return Shared::Result.success if actor.team?
        return Shared::Result.success if actor.school_admin? && actor.school_id == school.id && school.status == ACTIVE

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
