# 🧠 DOMAINE · Entities::Catalog::ImageSlot
# Rôle : un emplacement d'image annoncé par l'import dans le texte d'une fiche, « [[image: description]] » seul dans son paragraphe
# ADR  : 0089 · UDR : 0084
module Entities
  module Catalog
    ImageSlot = Data.define(:description) do
      # Un paragraphe dont tout le texte est l'emplacement ; ailleurs (au milieu d'une phrase), le texte n'est qu'un texte.
      def self.scan(html) = html.to_s.scan(ImageSlot::PATTERN).map { new(description: it.last.strip) }
    end
    ImageSlot::DESCRIPTION_MAX = 150
    # <p> à l'import, <div> une fois le texte enregistré par Trix (son bloc par défaut) : les deux sont des paragraphes.
    ImageSlot::PATTERN = %r{<(p|div)>\s*\[\[image:\s*([^\]<\s][^\]<]{0,#{ImageSlot::DESCRIPTION_MAX - 1}}?)\s*\]\]\s*</\1>}
  end
end
