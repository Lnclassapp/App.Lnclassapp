# 🧠 DOMAINE · Dtos::Communication::ArticleInput
# Rôle : saisie d'un article dans la modale de l'équipe : titre, résumé, texte HTML, signature, couverture, textes de remplacement
# ADR  : 0026, 0073 · UDR : 0065
module Dtos
  module Communication
    class ArticleInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      ARTICLE = Entities::Communication::Article
      IMAGE = Entities::Communication::ArticleImage
      # Une image du texte telle que la modale la montre (UDR-0065 §3.0), reconstruite par le contrôleur depuis le texte
      # envoyé et image_alts : un re-rendu 422 garde les images et leurs textes.
      Image = Data.define(:public_id, :sgid, :url, :alt)

      attribute :title, :string
      attribute :excerpt, :string
      # Le domaine ne connaît pas Action Text : le texte est le HTML de l'éditeur, assaini par l'adaptateur à l'écriture.
      attribute :body, :string
      attribute :signature, :string, default: "team"
      attribute :cover_public_id, :string
      attribute :cover_url, :string
      attribute :cover_alt, :string
      # image_alts : { public_id => texte de remplacement } (champs article[image_alts][<public_id>]).
      # images : Array<Image>, dans l'ordre du texte.
      attr_writer :image_alts, :images

      validates :title, presence: true, length: { maximum: ARTICLE::TITLE_MAX }
      validates :excerpt, length: { maximum: ARTICLE::EXCERPT_MAX }
      validates :body, length: { maximum: ARTICLE::BODY_MAX }
      validates :signature, inclusion: { in: ARTICLE::SIGNATURES }
      validates :cover_alt, length: { maximum: IMAGE::ALT_MAX }
      validate :image_alts_fit

      def title = super.to_s.squish
      def excerpt = super.to_s.squish.presence
      def body = super.to_s
      def signature = super.to_s.strip
      def cover_public_id = super.to_s.strip.presence
      def cover_alt = super.to_s.squish.presence
      def image_alts = @image_alts.to_h.to_h { |public_id, alt| [ public_id.to_s, alt.to_s.squish.presence ] }
      def images = @images || []

      # L'article tel qu'il serait enregistré, pour la règle de complétude de la publication (ADR-0073 §4.2) : la
      # couverture désignée, et les images du texte avec le texte de remplacement saisi pour chacune.
      def to_article(status:)
        ARTICLE.new(title:, excerpt:, body:, signature:, status:, cover_alt:,
                    cover: (IMAGE.new(public_id: cover_public_id) if cover_public_id),
                    images: images.map { IMAGE.new(public_id: it.public_id, alt: image_alts[it.public_id]) })
      end

      # Une erreur posée sur « image_alts.<public_id> » se lit dans image_alts.
      def read_attribute_for_validation(attribute)
        return image_alts[attribute.to_s.delete_prefix("image_alts.")] if attribute.to_s.start_with?("image_alts.")

        super
      end

      private

      def image_alts_fit
        image_alts.each do |public_id, alt|
          errors.add(:"image_alts.#{public_id}", :too_long, count: IMAGE::ALT_MAX) if alt.to_s.length > IMAGE::ALT_MAX
        end
      end
    end
  end
end
