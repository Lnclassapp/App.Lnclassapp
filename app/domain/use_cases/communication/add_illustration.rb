# 🧠 DOMAINE · UseCases::Communication::AddIllustration
# Rôle : l'équipe ajoute un dessin SVG à la bibliothèque d'illustrations d'annonce, gardé en formes reconstruites seulement
# ADR  : 0026, 0028, 0081 (§4.3) · UDR : 0075 (§3.5)
module UseCases
  module Communication
    class AddIllustration
      def initialize(illustrations:, drawings:, transaction:, policy:)
        @illustrations = illustrations
        @drawings = drawings
        @transaction = transaction
        @policy = policy
      end

      # dto : Dtos::Communication::IllustrationInput.
      # → Result(Entities::Communication::Illustration écrite) | :forbidden | :invalid (name:, file: [raison rédigée])
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        drawing = read(dto)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) if dto.errors.any?

        illustration = Entities::Communication::Illustration.new(
          name: dto.name, view_box: drawing.value[:view_box], shapes: drawing.value[:shapes], created_by_id: actor.user_id
        )
        Shared::Result.success(@transaction.call { @illustrations.create(illustration:) })
      end

      private

      # Le nom et le poids d'abord. Le dessin n'est lu que si le fichier a passé le poids ; la raison d'un refus rejoint
      # les erreurs de la saisie, pour que le nom et le fichier se corrigent ensemble. Seul ce que la lecture rend est
      # écrit : jamais le fichier envoyé (ADR-0081 §4.3).
      def read(dto)
        dto.valid?(:add)
        return if dto.errors.include?(:file)

        @drawings.read(bytes: dto.bytes).tap do |drawing|
          drawing.errors.fetch(:file, []).each { dto.errors.add(:file, it) }
        end
      end
    end
  end
end
