# 🧠 DOMAINE · Policies::Catalog::ManageTaxonomyPolicy
# Rôle : l'équipe gère niveaux, séries, liaisons niveau–série et matières
# ADR  : 0028, 0034
module Policies
  module Catalog
    class ManageTaxonomyPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
