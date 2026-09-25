# 🧠 DOMAINE · Dtos::Catalog::EssentialInput
# Rôle : saisie d'une fiche essentielle : nom (150), sous-titre (150), contenu HTML de l'éditeur riche, texte seul
# ADR  : 0026, 0035, 0047 · UDR : 0007, 0016
module Dtos
  module Catalog
    class EssentialInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Pièce jointe Trix ou Action Text, ou image : refusée en V1, même envoyée sans passer par l'éditeur.
      ATTACHMENT = /<\s*(?:action-text-attachment|figure|img)\b|data-trix-attachment/i

      # Le cours d'une nouvelle fiche ; une fiche modifiée ne change jamais de cours.
      attribute :course_slug, :string
      attribute :name, :string
      attribute :subtitle, :string
      # Le HTML produit par l'éditeur, gardé en chaîne : le domaine ne connaît pas Action Text.
      attribute :content, :string

      validates :name, presence: true, length: { maximum: Entities::Catalog::Essential::NAME_MAX }
      validates :subtitle, length: { maximum: Entities::Catalog::Essential::SUBTITLE_MAX }
      validate :text_only_content

      def name = super.to_s.squish
      def subtitle = super.to_s.squish
      def content = super.to_s

      def essential_attributes = { name:, subtitle:, content: }

      private

      def text_only_content
        errors.add(:content, :attachment) if content.match?(ATTACHMENT)
      end
    end
  end
end
