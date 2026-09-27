# 🧠 DOMAINE · Policies::School::ManageSchoolPolicy
# Rôle : l'équipe gère DRENA, établissements, génération des classes et import d'établissements
# ADR  : 0028, 0030, 0034, 0039
module Policies
  module School
    class ManageSchoolPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
