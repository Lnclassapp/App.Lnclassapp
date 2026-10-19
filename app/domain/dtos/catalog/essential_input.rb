# 🧠 DOMAINE · Dtos::Catalog::EssentialInput
# Rôle : saisie d'une fiche essentielle : nom (150), sous-titre (150), contenu HTML de l'éditeur riche et ses images, textes de remplacement
# ADR  : 0026, 0035, 0047, 0105 · UDR : 0007, 0016, 0129
module Dtos
  module Catalog
    class EssentialInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      ALT_MAX = Entities::Shared::ContentImage::ALT_MAX

      # Le cours d'une nouvelle fiche ; une fiche modifiée ne change jamais de cours.
      attribute :course_slug, :string
      attribute :name, :string
      attribute :subtitle, :string
      # Le HTML produit par l'éditeur, gardé en chaîne : le domaine ne connaît pas Action Text.
      attribute :content, :string
      # image_alts : { public_id => texte de remplacement } (champs essential[image_alts][<public_id>], ADR-0105). Les images
      # elles-mêmes sont des pièces jointes du contenu : le repository n'en garde que les images de fiche admises.
      attr_writer :image_alts

      validates :name, presence: true, length: { maximum: Entities::Catalog::Essential::NAME_MAX }
      validates :subtitle, length: { maximum: Entities::Catalog::Essential::SUBTITLE_MAX }
      validates :content, length: { maximum: Entities::Catalog::Essential::CONTENT_MAX }
      validate :image_alts_fit

      def name = super.to_s.squish
      def subtitle = super.to_s.squish
      def content = super.to_s

      def image_alts = @image_alts.to_h.to_h { |public_id, alt| [ public_id.to_s, alt.to_s.squish.presence ] }

      def essential_attributes = { name:, subtitle:, content: }

      # Les textes de remplacement saisis, que le repository écrit sur les images citées par le contenu.
      def images = image_alts.map { |public_id, alt| Entities::Shared::ContentImage.new(public_id:, alt:) }

      # Une erreur posée sur « image_alts.<public_id> » se lit dans image_alts (comme pour un article).
      def read_attribute_for_validation(attribute)
        return image_alts[attribute.to_s.delete_prefix("image_alts.")] if attribute.to_s.start_with?("image_alts.")

        super
      end

      private

      def image_alts_fit
        image_alts.each do |public_id, alt|
          errors.add(:"image_alts.#{public_id}", :too_long, count: ALT_MAX) if alt.to_s.length > ALT_MAX
        end
      end
    end
  end
end
