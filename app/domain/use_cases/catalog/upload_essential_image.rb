# 🧠 DOMAINE · UseCases::Catalog::UploadEssentialImage
# Rôle : l'équipe Administration et Contenu envoie une image de fiche, vérifiée et sans métadonnées, rattachée à aucune fiche
# ADR  : 0026, 0028, 0060, 0104 · UDR : 0129
module UseCases
  module Catalog
    class UploadEssentialImage
      MAX_PER_ESSENTIAL = Entities::Shared::ContentImage::MAX_PER_ESSENTIAL

      def initialize(images:, essentials:, policy:)
        @images = images
        @essentials = essentials
        @policy = policy
      end

      # dto : Dtos::Shared::ContentImageInput ; essential_slug : la fiche en cours de modification, nil à la création (le
      # plafond est alors tenu par l'éditeur). → Result(Ports::Catalog::EssentialImageStorePort::StoredImage)
      # | :forbidden | :not_found | :invalid (file: [raison])
      def call(actor:, dto:, essential_slug: nil)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        if essential_slug
          return Shared::Result.failure(:not_found) if @essentials.find_by_slug(slug: essential_slug).nil?
          return too_many(dto) if @images.count_for(essential_slug:) >= MAX_PER_ESSENTIAL
        end
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        Shared::Result.success(@images.store(data: dto.data, content_type: dto.content_type, width: dto.width, height: dto.height))
      end

      private

      def too_many(dto)
        dto.errors.add(:file, :too_many, count: MAX_PER_ESSENTIAL)
        Shared::Result.failure(:invalid, errors: dto.errors.to_hash)
      end
    end
  end
end
