# 🌐 UI · Catalog::CourseSheetTextHelper — le balisage en ligne d'un texte de fiche de cours
# Rôle : `sheet_text` échappe tout, puis ne rend que `[[clé|mot]]` (mot du lexique cliquable), `**gras**` et `*italique*` ; `$…$` reste à KaTeX
# ADR  : XXXX-fiche-de-cours-en-donnees-importees (contenu-en-blocs, chantier 318) · UDR : XXXX-fiche-de-cours-a-l-identique-des-maquettes
module Catalog
  module CourseSheetTextHelper
    MATH = /(\$[^$]+\$)/
    WORD = /\[\[([a-z0-9_]{1,40})\|([^\[\]|]{1,60})\]\]/
    BOLD = /\*\*(?=\S)(.+?)(?<=\S)\*\*/
    ITALIC = /(?<![*\w])\*(?=[^\s*])([^*]+?)(?<=[^\s*])\*(?![*\w])/

    # text : le texte du document (jamais du HTML : il est échappé d'abord). glossary : { clé => [titre, définition, exemple] }.
    # → String html_safe. Une marque dont la clé n'est pas au lexique ne laisse que son mot.
    def sheet_text(text, glossary: {})
      pieces = text.to_s.split(MATH).map { |piece| piece.match?(MATH) ? ERB::Util.html_escape(piece) : inline(piece, glossary) }
      safe_join(pieces)
    end

    private

    def inline(piece, glossary)
      html = ERB::Util.html_escape(piece).to_str
      html = html.gsub(WORD) { glossary_word(Regexp.last_match(1), Regexp.last_match(2), glossary) }
      html = html.gsub(BOLD, '<b>\1</b>').gsub(ITALIC, '<i>\1</i>')
      html.html_safe # rubocop:disable Rails/OutputSafety -- tout est échappé plus haut, seules nos balises s'ajoutent
    end

    # Le mot est déjà échappé : le bouton le reçoit tel quel. Sans JavaScript, il reste un mot lisible.
    def glossary_word(key, word, glossary)
      return word unless glossary.key?(key)

      tag.button(word.html_safe, type: "button", class: "sheet-word", # rubocop:disable Rails/OutputSafety -- déjà échappé
                 data: { action: "course-sheet--glossary#open", "course-sheet--glossary-key-param": key }).to_str
    end
  end
end
