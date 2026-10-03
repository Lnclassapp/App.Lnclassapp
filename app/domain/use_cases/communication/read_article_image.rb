# 🧠 DOMAINE · UseCases::Communication::ReadArticleImage
# Rôle : lire les octets d'une image d'article sous la règle de lecture de son article ; publique si l'article est publié
# ADR  : 0026, 0028, 0073 · UDR : 0064, 0065
module UseCases
  module Communication
    class ReadArticleImage
      # public : l'image d'un article publié se garde en cache public ; toute autre, lue par qui gère le blog, jamais.
      # data : lit les octets à l'appel, et seulement alors : un navigateur qui a déjà l'image publique n'en a pas besoin.
      Image = Data.define(:content_type, :public, :data)
      # Ce que lit Policies::Communication::ReadArticlePolicy ; nil : image rattachée à aucun article, lue comme un brouillon.
      ArticleState = Data.define(:status)

      def initialize(images:, policy:)
        @images = images
        @policy = policy
      end

      # → Result(Image) | :not_found (image inconnue ; brouillon, archivé ou non rattachée pour qui ne gère pas le blog)
      # Le fichier n'est jamais lu avant la règle de lecture : pour qui ne la voit pas, l'image ne coûte pas une lecture du bucket.
      def call(actor:, public_id:)
        image = @images.find(public_id:)
        return Shared::Result.failure(:not_found) if image.nil?
        # Une image n'a pas de page « retirée » : un archivé est introuvable, comme un brouillon (ADR-0073 §4.4).
        return Shared::Result.failure(:not_found) if @policy.call(actor:, article: ArticleState.new(status: image.article_status)).failure?

        Shared::Result.success(Image.new(content_type: image.content_type, public: image.article_status == "published",
                                         data: -> { @images.download(public_id:) }))
      end
    end
  end
end
