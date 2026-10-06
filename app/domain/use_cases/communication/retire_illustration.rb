# 🧠 DOMAINE · UseCases::Communication::RetireIllustration
# Rôle : l'équipe retire une illustration du choix des auteurs ; les annonces qui la portent la gardent, rien n'est supprimé
# ADR  : 0026, 0028, 0081 (§4.3) · UDR : 0075 (§3.5)
module UseCases
  module Communication
    class RetireIllustration
      def initialize(illustrations:, transaction:, policy:, clock:)
        @illustrations = illustrations
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # public_id : celui d'une illustration de l'équipe ; les 8 de base n'en ont pas (AV-10). Un second retrait garde
      # la première date (IllustrationRepositoryPort#retire).
      # → Result(Illustration retirée) | :forbidden | :not_found
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        illustration = @illustrations.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if illustration.nil?

        Shared::Result.success(@transaction.call { @illustrations.retire(id: illustration.id, at: @clock.now) })
      end
    end
  end
end
