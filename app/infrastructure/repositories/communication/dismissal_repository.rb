# 🔌 INFRA · Repositories::Communication::DismissalRepository
# Rôle : rejets d'annonces en base (message_dismissals), uniques par annonce et par compte : masquer vaut sur tous les appareils
# ADR  : 0045, 0078 · adaptateur de Ports::Communication::DismissalRepositoryPort
module Repositories
  module Communication
    class DismissalRepository
      include Ports::Communication::DismissalRepositoryPort

      # ON CONFLICT DO NOTHING sur l'index unique : un double clic ou deux appareils ne lèvent rien, le premier rejet reste.
      def dismiss(message_id:, user_id:, at:)
        Orm::MessageDismissal.insert_all([ { message_id:, user_id:, dismissed_at: at } ], unique_by: %i[message_id user_id])
        true
      end

      def restore(message_id:, user_id:) = Orm::MessageDismissal.where(message_id:, user_id:).delete_all.positive?
    end
  end
end
