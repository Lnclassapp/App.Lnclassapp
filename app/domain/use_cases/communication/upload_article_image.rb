# 🧠 DOMAINE · UseCases::Communication::UploadArticleImage
# Rôle : l'équipe Administration et Contenu envoie une image d'article, vérifiée et sans métadonnées, rattachée à aucun article
# ADR  : 0026, 0028, 0060, 0074 · UDR : 0067
module UseCases
  module Communication
    class UploadArticleImage
      MAX_PER_ARTICLE = Entities::Communication::ArticleImage::MAX_PER_ARTICLE

      def initialize(images:, articles:, policy:)
        @images = images
        @articles = articles
        @policy = policy
      end

      # dto : Dtos::Communication::ArticleImageInput ; article_public_id : l'article en cours de modification, nil à la
      # création (la limite est alors tenue par l'éditeur, puis par l'enregistrement).
      # → Result(Ports::Communication::ArticleImageStorePort::StoredImage) | :forbidden | :not_found | :invalid (file: [raison])
      def call(actor:, dto:, article_public_id: nil)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        if article_public_id
          article = @articles.find_by_public_id(public_id: article_public_id)
          return Shared::Result.failure(:not_found) if article.nil?
          return too_many(dto) if article.images.size >= MAX_PER_ARTICLE
        end
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        Shared::Result.success(@images.store(data: dto.data, content_type: dto.content_type, width: dto.width, height: dto.height))
      end

      private

      # La raison est rédigée comme celles du fichier : une seule source de messages, les clés du DTO.
      def too_many(dto)
        dto.errors.add(:file, :too_many, count: MAX_PER_ARTICLE)
        Shared::Result.failure(:invalid, errors: dto.errors.to_hash)
      end
    end
  end
end
