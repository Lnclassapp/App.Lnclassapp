# 🧠 DOMAINE · UseCases::Communication::RenameIllustration
# Rôle : l'équipe renomme une illustration de la bibliothèque ; son dessin ne change pas
# ADR  : 0026, 0028, 0081 (§4.3) · UDR : 0075 (§3.5)
module UseCases
  module Communication
    class RenameIllustration
      def initialize(illustrations:, transaction:, policy:)
        @illustrations = illustrations
        @transaction = transaction
        @policy = policy
      end

      # public_id : celui d'une illustration de l'équipe ; les 8 de base n'en ont pas (AV-10).
      # dto : Dtos::Communication::IllustrationInput, son nom seul.
      # → Result(Illustration renommée) | :forbidden | :not_found | :invalid (name:)
      def call(actor:, public_id:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        illustration = @illustrations.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if illustration.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        Shared::Result.success(@transaction.call { @illustrations.rename(id: illustration.id, name: dto.name) })
      end
    end
  end
end
