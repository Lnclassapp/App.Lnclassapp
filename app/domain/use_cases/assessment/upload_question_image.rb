# 🧠 DOMAINE · UseCases::Assessment::UploadQuestionImage
# Rôle : l'équipe Administration et Contenu envoie l'image d'une question, vérifiée et sans métadonnées, rattachée à aucune question
# ADR  : 0026, 0028, 0060, 0089 · UDR : 0084
module UseCases
  module Assessment
    class UploadQuestionImage
      # Le rôle terrain gère des exercices sans envoyer d'image (PRD images-dans-les-cours §2, comme le blog : ADR-0038).
      TEAM_ROLES = %w[admin content].freeze

      def initialize(images:, policy:)
        @images = images
        @policy = policy
      end

      # dto : Dtos::Shared::ContentImageInput.
      # → Result(Ports::Assessment::QuestionImageStorePort::StoredImage) | :forbidden | :invalid (file: [raison])
      def call(actor:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:forbidden) unless TEAM_ROLES.include?(actor.team_role)
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        Shared::Result.success(@images.store(data: dto.data, content_type: dto.content_type, width: dto.width, height: dto.height))
      end
    end
  end
end
