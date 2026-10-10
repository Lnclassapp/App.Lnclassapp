# 🧠 DOMAINE · Entities::Catalog::ImageSlot
# Rôle : un emplacement d'image annoncé par l'import dans le texte d'une fiche, « [[image: description]] » seul dans son paragraphe
# ADR  : 0089 · UDR : 0084
module Entities
  module Catalog
    ImageSlot = Data.define(:description) do
      # Un paragraphe dont tout le texte est l'emplacement ; ailleurs (au milieu d'une phrase), le texte n'est qu'un texte.
      def self.scan(html) = html.to_s.scan(ImageSlot::PATTERN).map { new(description: it.first.strip) }
    end
    ImageSlot::DESCRIPTION_MAX = 150
    ImageSlot::PATTERN = %r{<p>\s*\[\[image:\s*([^\]<\s][^\]<]{0,#{ImageSlot::DESCRIPTION_MAX - 1}}?)\s*\]\]\s*</p>}
  end
end
