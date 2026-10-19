# 🧠 DOMAINE · Entities::Catalog::ImageSlot
# Rôle : un emplacement d'image annoncé par l'import dans le texte d'une fiche, « [[image: description]] » seul dans son paragraphe
# ADR  : 0105 · UDR : 0129
module Entities
  module Catalog
    ImageSlot = Data.define(:description) do
      # Un paragraphe dont tout le texte est l'emplacement ; ailleurs (au milieu d'une phrase), le texte n'est qu'un texte.
      def self.scan(html) = html.to_s.scan(ImageSlot::PATTERN).map { new(description: it.last.strip) }

      # Les blocs dont tout le texte a la forme « [[image: …]] » sans que le motif les lise (dans une liste ou un titre,
      # mis en gras, vides, trop longs) : sans cela, ils ne seraient comptés nulle part et l'élève les lirait tels quels.
      # Au milieu d'une phrase, le texte reste un texte.
      def self.malformed_count(html)
        attempts = html.to_s.scan(ImageSlot::BLOCK).count do |_tag, inner|
          text = inner.gsub(/<[^>]*>/, "").strip
          text.start_with?(ImageSlot::MARKER) && text.end_with?("]]")
        end
        attempts - scan(html).size
      end
    end
    ImageSlot::DESCRIPTION_MAX = 150
    ImageSlot::MARKER = "[[image:"
    ImageSlot::BLOCK = %r{<(p|div|li|h[1-6]|blockquote)\b[^>]*>(.*?)</\1>}m
    # <p> à l'import, <div> une fois le texte enregistré par Trix (son bloc par défaut) : les deux sont des paragraphes.
    ImageSlot::PATTERN = %r{<(p|div)>\s*\[\[image:\s*([^\]<\s][^\]<]{0,#{ImageSlot::DESCRIPTION_MAX - 1}}?)\s*\]\]\s*</\1>}
  end
end
