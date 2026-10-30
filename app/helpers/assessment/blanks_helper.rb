# 🌐 UI · Assessment::BlanksHelper — l'énoncé d'une question découpé en texte et en cases
# Rôle : un `___` est une case, numérotée de 0 dans l'ordre de l'énoncé ; la fiche (styles du cahier) et la copie (styles de l'application) s'en servent
# ADR  : XXXX-questions-a-plusieurs-cases-et-indice (§4) · UDR : XXXX-je-m-entraine-dans-la-fiche (§3.3)
module Assessment
  module BlanksHelper
    MARKER = "___".freeze

    # « AN (cm) = ___  MN (cm) = ___ » → [[:text, "AN (cm) = "], [:blank, 0], [:text, "  MN (cm) = "], [:blank, 1]]
    # Aucun morceau de texte vide. Un énoncé sans `___` reste un seul morceau de texte : la case unique d'une question chiffrée sans
    # marqueur est placée après le texte par la vue. → Array<[:text, String] | [:blank, Integer]>
    def blank_segments(content)
      segments = []
      blank = -1
      content.to_s.split(MARKER, -1).each_with_index do |text, index|
        segments << [ :blank, blank += 1 ] if index.positive?
        segments << [ :text, text ] unless text.empty?
      end
      segments
    end
  end
end
