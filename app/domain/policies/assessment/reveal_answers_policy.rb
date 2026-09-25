# 🧠 DOMAINE · Policies::Assessment::RevealAnswersPolicy
# Rôle : montrer les bonnes réponses : équipe et enseignant, pour tout exercice qu'ils lisent ; jamais l'élève
# ADR  : 0028, 0054
module Policies
  module Assessment
    class RevealAnswersPolicy
      # Décision du porteur (2026-09-25), contre l'ADR-0028 : l'enseignant prépare avec la correction,
      # même pour un exercice pas encore assigné ; l'élève ne la voit jamais, pas même après sa tentative.
      # exercise répond à readable_chain_published?
      def call(actor:, exercise:)
        return Shared::Result.failure(:forbidden) unless actor&.team? || actor&.teacher?

        Policies::Catalog::ReadPublishedPolicy.new.call(actor:, content: exercise)
      end
    end
  end
end
