# 🧠 DOMAINE · Entities::Communication::Article
# Rôle : un article du blog : plafonds, signature, cycle des contenus, et règle de complétude de sa publication
# ADR  : 0035, 0073 · UDR : 0065
module Entities
  module Communication
    class Article
      include ActiveModel::Model

      TITLE_MAX = 120
      EXCERPT_MAX = 200
      # Caractères de HTML, sous le budget de 150 Ko de la page (ADR-0067).
      BODY_MAX = 100_000
      SIGNATURES = %w[team author].freeze
      TRANSITIONS = Entities::Shared::ContentStatus::TRANSITIONS
      # Le domaine ne connaît pas Action Text : le texte est du HTML, dont on ne lit que le texte visible.
      TAGS = /<[^>]*>/
      SPACES = /&nbsp;| /

      # cover : ArticleImage | nil ; images : les images du texte, dans l'ordre du texte, chacune avec son alt.
      attr_accessor :id, :public_id, :slug, :title, :excerpt, :body, :signature, :status, :author_id, :cover, :cover_alt,
                    :published_at, :archived_at, :reads_count, :created_at, :updated_at
      attr_writer :images

      validates :title, presence: true, length: { maximum: TITLE_MAX }
      validates :excerpt, length: { maximum: EXCERPT_MAX }
      validates :body, length: { maximum: BODY_MAX }
      validates :signature, inclusion: { in: SIGNATURES }
      validates :status, inclusion: { in: Entities::Shared::ContentStatus::VALUES }
      validate :complete_for_publication, on: :publication

      # Ses messages sont ceux que l'équipe lit dans la modale (UDR-0065 §3.5) : une seule source, les clés de la saisie.
      def self.lookup_ancestors = [ Dtos::Communication::ArticleInput ]

      def images = @images || []

      def draft? = status == "draft"
      def published? = status == "published"
      def archived? = status == "archived"

      # Lue par la publication et par l'enregistrement d'un article publié (ADR-0073 §4.2). → {} si l'article est
      # publiable tel quel ; sinon Hash{champ => [message]}, champs dans l'ordre du formulaire : title, excerpt,
      # cover_alt, body, :"image_alts.<public_id>" (numérotée dans l'ordre du texte).
      def publication_errors
        valid?(:publication) ? {} : errors.to_hash
      end

      # Une erreur posée sur « image_alts.<public_id> » n'a pas d'attribut à lire.
      def read_attribute_for_validation(attribute)
        return if attribute.to_s.start_with?("image_alts.")

        super
      end

      private

      def complete_for_publication
        errors.add(:excerpt, :blank) if excerpt.to_s.strip.empty?
        errors.add(:cover_alt, :blank) if cover && cover_alt.to_s.strip.empty?
        errors.add(:body, :blank) if body.to_s.gsub(TAGS, " ").gsub(SPACES, " ").strip.empty?
        errors.add(:body, :too_many_images, count: ArticleImage::MAX_PER_ARTICLE) if images.size > ArticleImage::MAX_PER_ARTICLE
        images.each_with_index do |image, index|
          errors.add(:"image_alts.#{image.public_id}", :image_alt_blank, number: index + 1) unless image.alt?
        end
      end
    end
  end
end
