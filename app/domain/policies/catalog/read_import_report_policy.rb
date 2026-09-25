# 🧠 DOMAINE · Policies::Catalog::ReadImportReportPolicy
# Rôle : l'équipe suit les rapports d'import
# ADR  : 0028, 0039
module Policies
  module Catalog
    class ReadImportReportPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
