# 🧠 DOMAINE · Policies::Assessment::StartSessionPolicy
# Rôle : un élève démarre un exercice publié dont les parents sont publiés, sans exigence d'assignation
# ADR  : 0028, 0035, 0054
module Policies
  module Assessment
    class StartSessionPolicy
      # exercise : répond à readable_chain_published? (Entities::Assessment::Exercise)
      def call(actor:, exercise:)
        return Shared::Result.failure(:forbidden) unless actor&.student?
        return Shared::Result.failure(:forbidden, errors: { base: [ :not_published ] }) unless exercise.readable_chain_published?

        Shared::Result.success
      end
    end
  end
end
