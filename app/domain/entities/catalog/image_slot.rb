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
      #
      # Le motif est à coût quadratique sur un texte hostile (« <p> » sans fin, répétés) : il a un délai par recherche, et
      # tout l'appel a une échéance (menace.md, n° 13). Un texte segmenté (« <li> » × 200 puis « <p></p> », répété) fait de
      # chaque recherche un succès lent : le délai par recherche ne le voit jamais, l'échéance globale l'arrête.
      # Lève ImageSlot::Unreadable passé l'un ou l'autre : le texte n'est pas « mal écrit », il est trop complexe à relire.
      # within : la durée totale permise, en secondes (réglable pour les tests).
      def self.malformed_count(html, within: ImageSlot::DEADLINE)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + within
        attempts = 0
        html.to_s.scan(ImageSlot::BLOCK) do |_tag, inner|
          raise ImageSlot::Unreadable if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          text = inner.gsub(/<[^>]*>/, "").strip
          attempts += 1 if text.start_with?(ImageSlot::MARKER) && text.end_with?("]]")
        end
        attempts - scan(html).size
      rescue Regexp::TimeoutError
        raise ImageSlot::Unreadable
      end
    end
    ImageSlot::DESCRIPTION_MAX = 150
    ImageSlot::MARKER = "[[image:"
    # Un texte qui dépasse l'un ou l'autre n'est plus relu (ADR-0105 §4.3) : refusé comme « trop complexe », jamais compté.
    class ImageSlot::Unreadable < StandardError; end
    ImageSlot::BLOCK_TIMEOUT = 0.25
    ImageSlot::DEADLINE = 0.5
    ImageSlot::BLOCK = Regexp.new(%r{<(p|div|li|h[1-6]|blockquote)\b[^>]*>(.*?)</\1>}.source, Regexp::MULTILINE,
                                  timeout: ImageSlot::BLOCK_TIMEOUT)
    # <p> à l'import, <div> une fois le texte enregistré par Trix (son bloc par défaut) : les deux sont des paragraphes.
    ImageSlot::PATTERN = %r{<(p|div)>\s*\[\[image:\s*([^\]<\s][^\]<]{0,#{ImageSlot::DESCRIPTION_MAX - 1}}?)\s*\]\]\s*</\1>}
  end
end
