# 🧠 DOMAINE · Entities::Catalog::RevisionPreview
# Rôle : la coupe de la « Fiche de révision » d'une leçon : 50 mots de texte, puis la fin du bloc qui atteint le seuil
# ADR  : 0110-fiche-de-cours-en-donnees-importees, 0113, 0116-fiche-de-revision-par-notion · UDR : 0139 §3.2, 0141-fiche-de-revision-en-quatre-blocs §3.1, 0147
module Entities
  module Catalog
    class RevisionPreview
      LIMIT = 50

      MATH = /\$[^$]+\$/
      # Les blocs d'une notion, dans l'ordre de lecture ; la figure se place entre La méthode et l'exemple.
      REMEMBER = 0
      METHOD = 1
      FIGURE = 2
      EXAMPLE = 3
      PITFALL = 4

      GLOSSARY_MARK = /\[\[[a-z0-9_]{1,40}\|([^\[\]|]{1,60})\]\]/

      attr_reader :total, :limit

      # Les mots du texte seul : une formule `$…$` vaut un mot, une marque du lexique son mot, le balisage gras / italique rien.
      def self.count_words(text)
        plain = text.to_s.gsub("\\$", "").gsub(MATH, " x ").gsub(GLOSSARY_MARK, '\1')
        plain.split.count { it.match?(/[[:alnum:]]/) }
      end

      # pages : celles du document d'une fiche de cours (clés en chaînes). Clés des blocs : [page, section, bloc], de 0 à n - 1.
      def self.for_sheet(pages, limit: LIMIT)
        units = []
        pages.each_with_index do |page, page_index|
          carry = header_words(page["header"])
          page.fetch("sections", []).each_with_index do |section, section_index|
            carry += count_words(section["title"])
            section.fetch("blocks", []).each_with_index do |block, block_index|
              units << [ [ page_index, section_index, block_index ], carry + block_words(block) ]
              carry = 0
            end
          end
        end
        new(units, limit:)
      end

      # sections : [{ title: String | nil, blocks: [texte de chaque bloc] }], le texte de la leçon d'abord, puis une notion par
      # entrée. Clés des blocs : [section, bloc], de 0 à n - 1.
      def self.for_texts(sections, limit: LIMIT)
        units = []
        sections.each_with_index do |section, section_index|
          carry = count_words(section[:title])
          section.fetch(:blocks).each_with_index do |text, block_index|
            units << [ [ section_index, block_index ], carry + count_words(text) ]
            carry = 0
          end
        end
        new(units, limit:)
      end

      # sheets : [NotionSheet] dans l'ordre de la leçon. Clés des blocs : [notion, REMEMBER | METHOD | FIGURE | EXAMPLE | PITFALL] ; la
      # figure (présente quand la notion en cite une) ne porte aucun mot.
      def self.for_notions(sheets, limit: LIMIT)
        units = []
        sheets.each_with_index do |sheet, index|
          units << [ [ index, REMEMBER ], count_words(sheet.remember) ]
          units << [ [ index, METHOD ], sheet.method_steps.sum { count_words(it) } ]
          units << [ [ index, FIGURE ], 0 ] if sheet.figure_key
          units << [ [ index, EXAMPLE ], count_words(sheet.example_statement) + sheet.example_steps.sum { count_words(it) } ]
          units << [ [ index, PITFALL ], count_words(sheet.pitfall) ]
        end
        new(units, limit:)
      end

      def self.header_words(header)
        return 0 unless header

        count_words(header["title"]) + count_words(header["intro"])
      end

      # Figure, média, exercice corrigé, « Je m'entraîne » et rédaction ne portent aucun mot.
      def self.block_words(block)
        case block["type"]
        when "paragraph", "simple" then count_words(block["text"])
        when "box" then count_words(block["label"]) + block.fetch("paragraphs", []).sum { count_words(it) }
        when "steps" then count_words(block["label"]) + block.fetch("items", []).sum { count_words(it) }
        when "table" then table_words(block)
        when "figure", "media", "exercise", "practice", "writing" then 0
        else raise ArgumentError, "unknown block type: #{block["type"].inspect}"
        end
      end

      def self.table_words(block)
        cells = block.fetch("headers", []) + block.fetch("rows", []).flatten
        count_words(block["caption"]) + cells.sum { count_words(it) }
      end

      private_class_method :header_words, :block_words, :table_words

      # units : [[clé, mots]] dans l'ordre de lecture.
      def initialize(units, limit: LIMIT)
        @units = units
        @limit = limit
        @total = units.sum(&:last)
        @cut_index = find_cut_index
      end

      def cut? = !@cut_index.nil?

      # Vrai pour un bloc, une section ou une page qui vient entièrement après la coupe : `rest?(page, section, bloc)`,
      # `rest?(page, section)`, `rest?(page)`. Une clé inconnue reste visible.
      def rest?(*key)
        return false unless cut?

        index = @units.index { |unit_key, _| unit_key.first(key.size) == key }
        !index.nil? && index > @cut_index
      end

      private

      # Le premier bloc qui porte le total à `limit`, à condition qu'il reste quelque chose après lui.
      def find_cut_index
        return unless @total > @limit

        running = 0
        index = @units.index { |_, words| (running += words) >= @limit }
        index if index && index < @units.size - 1
      end
    end
  end
end
