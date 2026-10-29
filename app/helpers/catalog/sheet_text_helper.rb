# 🌐 UI · Catalog::SheetTextHelper — le balisage en ligne d'un texte de fiche de révision ou de sujet d'exercice
# Rôle : `sheet_text` échappe tout, puis ne rend que `**gras**` et `*italique*` ; `$…$` reste à KaTeX ; une marque `[[clé|mot]]` ne laisse que son mot
# ADR  : XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.5, lexique retiré) · UDR : 0137, XXXX-fiche-de-revision-en-quatre-blocs
module Catalog
  module SheetTextHelper
    MATH = /(\$[^$]+\$)/
    WORD = /\[\[([a-z0-9_]{1,40})\|([^\[\]|]{1,60})\]\]/
    BOLD = /\*\*(?=\S)(.+?)(?<=\S)\*\*/
    ITALIC = /(?<![*\w])\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*(?![*\w])/

    # text : le texte du document (jamais du HTML : il est échappé d'abord). → String html_safe.
    def sheet_text(text)
      pieces = text.to_s.split(MATH).map { |piece| piece.match?(MATH) ? ERB::Util.html_escape(piece) : inline(piece) }
      safe_join(pieces)
    end

    private

    def inline(piece)
      html = ERB::Util.html_escape(piece).to_str
      html = html.gsub(WORD) { Regexp.last_match(2) }
      html = html.gsub(BOLD, '<b>\1</b>').gsub(ITALIC, '<i>\1</i>')
      html.html_safe # rubocop:disable Rails/OutputSafety -- tout est échappé plus haut, seules nos balises s'ajoutent
    end
  end
end
