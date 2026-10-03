# 🔌 INFRA · Queries::Communication::ArticleFormImagesQuery
# Rôle : images du texte d'un article pour la modale (ordre du texte, sgid, adresse, texte de remplacement), couverture
# ADR  : 0074 · UDR : 0067
module Queries
  module Communication
    class ArticleFormImagesQuery
      Image = Dtos::Communication::ArticleInput::Image
      IMAGE_MODEL = "Orm::ArticleImage"

      # body : le HTML enregistré, ou celui que Trix envoie (figures) ; image_alts : la saisie, { public_id => alt }.
      # Seules les images de l'article, ou à personne encore, sont montrées : l'assainisseur retirerait les autres.
      # → Array<Image>, dans l'ordre du texte ; un texte de remplacement absent de la saisie garde sa valeur enregistrée.
      def call(body:, image_alts: {}, article_public_id: nil)
        ids = cited_ids(body)
        return [] if ids.empty?

        images = admissible(article_public_id).where(id: ids).index_by(&:id)
        ids.filter_map { images[it] }.map do |image|
          alt = image_alts.key?(image.public_id) ? image_alts[image.public_id] : image.alt
          Image.new(public_id: image.public_id, sgid: image.attachable_sgid, url: url(image.public_id), alt:)
        end
      end

      # → l'adresse de la couverture désignée, si elle est à l'article ou à personne encore ; sinon nil.
      def cover_url(public_id:, article_public_id: nil)
        url(public_id) if public_id && admissible(article_public_id).exists?(public_id:)
      end

      private

      def admissible(article_public_id)
        scope = Orm::ArticleImage.left_joins(:article)
        scope.where(article_id: nil).or(scope.where(articles: { public_id: article_public_id }))
      end

      # Le texte est d'abord canonisé (figures de Trix → pièces jointes) ; les sgid se lisent sans requête.
      def cited_ids(body)
        html = ActionText::Content.new(body.to_s).to_html
        Nokogiri::HTML5.fragment(html).css(ActionText::Attachment.tag_name).filter_map do |node|
          gid = SignedGlobalID.parse(node["sgid"].to_s, for: ActionText::Attachable::LOCATOR_NAME)
          gid.model_id.to_i if gid&.model_name == IMAGE_MODEL
        end.uniq
      end

      def url(public_id) = Rails.application.routes.url_helpers.blog_image_path(public_id)
    end
  end
end
