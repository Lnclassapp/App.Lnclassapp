# 🧠 DOMAINE · Policies::Catalog::ManageContentPolicy
# Rôle : l'équipe gère cours, fiches, exercices, publication, archivage et imports de contenu
# ADR  : 0028, 0035, 0039
module Policies
  module Catalog
    class ManageContentPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
