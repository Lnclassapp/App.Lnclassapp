# 🌐 UI · Catalog::SheetTextHelper — le balisage en ligne d'un texte de fiche de révision ou de sujet d'exercice
# Rôle : `sheet_text` échappe tout, puis ne rend que `**gras**` et `*italique*` ; `$…$` et `$$…$$` restent à KaTeX ; une marque `[[clé|mot]]` ne laisse que son mot
# ADR  : 0116-fiche-de-revision-par-notion-et-figures-parametrees (§4.5, lexique retiré) · UDR : 0137, 0141-fiche-de-revision-en-quatre-blocs
module Catalog
  module SheetTextHelper
    # `$$…$$` d'abord : lu comme deux `$…$`, il décalait tous les dollars suivants (lecons-defauts-affichage).
    MATH = /\$\$.+?\$\$|\$[^$]+\$/m
    # Une formule est mise de côté sous ce repère, le temps du gras et de l'italique : un gras peut l'entourer.
    SLOT = /\u0001(\d+)\u0002/
    WORD = /\[\[([a-z0-9_]{1,40})\|([^\[\]|]{1,60})\]\]/
    BOLD = /\*\*(?=\S)(.+?)(?<=\S)\*\*/
    ITALIC = /(?<![*\w])\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*(?![*\w])/

    # text : le texte du document (jamais du HTML : il est échappé d'abord). → String html_safe.
    def sheet_text(text)
      formulas = []
      plain = text.to_s.delete("\u0001\u0002").gsub(MATH) { "\u0001#{formulas.push(it).size - 1}\u0002" }
      html = ERB::Util.html_escape(plain).to_str
      html = html.gsub(WORD) { Regexp.last_match(2) }
      html = html.gsub(BOLD, '<b>\1</b>').gsub(ITALIC, '<i>\1</i>')
      html = html.gsub(SLOT) { ERB::Util.html_escape(formulas.fetch(Regexp.last_match(1).to_i)) }
      html.html_safe # rubocop:disable Rails/OutputSafety -- tout est échappé plus haut, seules nos balises s'ajoutent
    end
  end
end
