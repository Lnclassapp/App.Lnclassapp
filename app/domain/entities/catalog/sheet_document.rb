# 🧠 DOMAINE · Entities::Catalog::SheetDocument
# Rôle : valide le document d'une fiche de cours (pages, sections, blocs, lexique) lu comme un fichier hostile
# ADR  : XXXX-fiche-de-cours-en-donnees-importees (contenu-en-blocs, #318), 0039
module Entities
  module Catalog
    class SheetDocument
      # page, section, position : 1 pour le premier, nil quand l'erreur est plus haut. detail : la clé ou le chemin en cause.
      Error = Data.define(:page, :section, :position, :reason, :detail) do
        def to_s
          where = [ ("page #{page}" if page), ("section #{section}" if section), ("bloc #{position}" if position) ].compact
          [ where.empty? ? "document" : where.join(", "), " : ", reason, (" (#{detail})" if detail) ].join
        end
      end

      BLOCK_TYPES = %w[paragraph box simple steps table figure media exercise practice writing].freeze
      MEDIA_KINDS = %w[thales_figure lens_simulator lens_construction argument_highlighter].freeze
      FIGURE_KINDS = %w[lens_diagrams].freeze
      GENERATOR_KINDS = %w[thales_ratio bank].freeze
      BOX_TONES = %w[property remember method].freeze
      INPUTS = %w[numeric choice].freeze

      SIZE_MAX = 1024 * 1024
      PAGES_MAX = 10
      SECTIONS_MAX = 12
      BLOCKS_MAX = 30
      FIELDS_MAX = 12
      ITEMS_MAX = 30
      PARAGRAPHS_MAX = 10
      ROWS_MAX = 30
      COLUMNS_MAX = 8
      OPTIONS_MIN = 2
      OPTIONS_MAX = 8
      BANK_MAX = 50
      CONNECTORS_MAX = 40
      GLOSSARY_MAX = 100
      PARAMS_MAX = 12
      TEXT_MAX = 2000
      SHORT_MAX = 200
      TITLE_MAX = 80
      DEFINITION_MAX = 600
      EXAMPLE_MAX = 400
      WORDS_MAX = 1000
      PARAGRAPH_COUNT_MAX = 20
      NUMBER_MAX = 1_000_000

      GLOSSARY_KEY = /\A[a-z0-9_]{1,40}\z/
      FIELD_ID = /\A[a-z0-9_]{1,20}\z/
      PARAM_KEY = /\A[a-z][a-z0-9_]{0,29}\z/
      MARK = /\A([a-z0-9_]{1,40})\|([^\[\]|]{1,60})\z/
      # Aucun lien sortant ni ressource distante (menace de l'ADR). « (MN) // (BC) » s'écrit librement : seul « :// » est un schéma.
      URL = %r{://|www\.|mailto:|javascript:|data:}i

      def initialize(document)
        @document = deep_stringify(document)
        @errors = nil
      end

      def valid? = errors.empty?

      def errors
        @errors ||= begin
          @found = []
          @page = @section = @position = nil
          validate
          @found
        end
      end

      def pages = @document.is_a?(Hash) && @document["pages"].is_a?(Array) ? @document["pages"] : []

      def glossary = @document.is_a?(Hash) && @document["glossary"].is_a?(Hash) ? @document["glossary"] : {}

      private

      def deep_stringify(value)
        case value
        when Hash then value.to_h { |key, item| [ key.to_s, deep_stringify(item) ] }
        when Array then value.map { deep_stringify(it) }
        else value
        end
      end

      def fail!(reason, detail = nil)
        @found << Error.new(page: @page, section: @section, position: @position, reason:, detail:)
        nil
      end

      def validate
        return fail!(:wrong_type) unless @document.is_a?(Hash)
        # La taille d'abord : on ne parcourt pas un document démesuré.
        size = serialized_size
        return fail!(:wrong_type, "json") if size.nil?
        return fail!(:too_large) if size > SIZE_MAX

        keys!(@document, required: %w[pages glossary])
        validate_glossary
        validate_pages
      end

      # nil quand le document ne s'écrit pas en JSON (NaN, objet étranger) : il ne vient pas d'un fichier JSON.
      def serialized_size
        JSON.generate(@document).bytesize
      rescue JSON::GeneratorError
        nil
      end

      # ---- Contrôles élémentaires -------------------------------------------------------------------------------

      # Les clés d'un objet : les inconnues et les absentes sont refusées. → le Hash, ou nil
      def keys!(value, required:, optional: [])
        return fail!(:wrong_type) unless value.is_a?(Hash)

        (value.keys - required - optional).each { fail!(:unknown_key, it) }
        (required - value.keys).each { fail!(:missing_key, it) }
        value
      end

      def list(value, key, max:, min: 1)
        return fail!(:wrong_type, key) unless value.is_a?(Array)
        return fail!(min == 1 ? :blank : :too_few, key) if value.size < min
        return fail!(:too_many, key) if value.size > max

        value
      end

      def number(value, key)
        return fail!(:wrong_type, key) unless value.is_a?(Numeric) && (value.is_a?(Integer) || value.finite?)

        fail!(:out_of_range, key) if value.abs > NUMBER_MAX
      end

      def integer(value, key, range)
        return fail!(:wrong_type, key) unless value.is_a?(Integer)

        fail!(:out_of_range, key) unless range.cover?(value)
      end

      def boolean(value, key) = (fail!(:wrong_type, key) unless [ true, false ].include?(value))

      # Une chaîne : bornée, sans HTML, sans URL ; le lexique et les formules sont contrôlés si `inline`.
      def text(value, key, max: TEXT_MAX, blank: false, inline: true)
        return fail!(:wrong_type, key) unless value.is_a?(String)
        return fail!(:blank, key) if !blank && value.strip.empty?
        return fail!(:too_long, key) if value.length > max
        return fail!(:html_forbidden, key) if value.include?("<")
        return fail!(:url_forbidden, key) if value.match?(URL)

        inline_marks(value, key) if inline
      end

      def inline_marks(value, key)
        rest = value.gsub(/\[\[(.*?)\]\]/m) do
          mark = Regexp.last_match(1)
          match = MARK.match(mark)
          if match.nil? then fail!(:malformed_mark, key)
          elsif !glossary.key?(match[1]) then fail!(:unknown_glossary_key, match[1])
          end
          ""
        end
        fail!(:malformed_mark, key) if rest.include?("[[") || rest.include?("]]")
        fail!(:unbalanced_math, key) if value.gsub("\\$", "").count("$").odd?
      end

      # ---- Lexique ----------------------------------------------------------------------------------------------

      def validate_glossary
        entries = @document["glossary"]
        return fail!(:wrong_type, "glossary") unless entries.is_a?(Hash)
        return fail!(:too_many, "glossary") if entries.size > GLOSSARY_MAX

        entries.each do |key, entry|
          fail!(:invalid_glossary_key, key) unless GLOSSARY_KEY.match?(key)
          glossary_entry(entry, key)
        end
      end

      def glossary_entry(entry, key)
        return fail!(:wrong_type, "glossary.#{key}") unless entry.is_a?(Array) && entry.size == 3

        title, definition, example = entry
        text(title, "glossary.#{key}.title", max: TITLE_MAX, inline: false)
        text(definition, "glossary.#{key}.definition", max: DEFINITION_MAX, inline: false)
        text(example, "glossary.#{key}.example", max: EXAMPLE_MAX, blank: true, inline: false)
      end

      # ---- Pages, sections, blocs -------------------------------------------------------------------------------

      def validate_pages
        pages = list(@document["pages"], "pages", max: PAGES_MAX)
        pages&.each_with_index do |page, index|
          @page = index + 1
          validate_page(page)
        end
        @page = nil
      end

      def validate_page(page)
        return unless keys!(page, required: %w[sections], optional: %w[header])

        validate_header(page["header"]) if page.key?("header")
        sections = list(page["sections"], "sections", max: SECTIONS_MAX)
        sections&.each_with_index do |section, index|
          @section = index + 1
          validate_section(section)
        end
        @section = nil
      end

      def validate_header(header)
        return unless keys!(header, required: [], optional: %w[eyebrow_left eyebrow_right title intro])

        %w[eyebrow_left eyebrow_right title].each { text(header[it], "header.#{it}", max: SHORT_MAX) if header.key?(it) }
        text(header["intro"], "header.intro") if header.key?("intro")
      end

      def validate_section(section)
        return unless keys!(section, required: %w[title blocks])

        text(section["title"], "title", max: SHORT_MAX)
        blocks = list(section["blocks"], "blocks", max: BLOCKS_MAX)
        blocks&.each_with_index do |block, index|
          @position = index + 1
          validate_block(block)
        end
        @position = nil
      end

      def validate_block(block)
        return fail!(:wrong_type) unless block.is_a?(Hash)
        return fail!(:missing_key, "type") unless block.key?("type")

        type = block["type"]
        return fail!(:unknown_type, type.to_s[0, 40]) unless BLOCK_TYPES.include?(type)

        send(:"block_#{type}", block)
      end

      def block_paragraph(block)
        keys!(block, required: %w[type text])
        text(block["text"], "text")
      end

      alias_method :block_simple, :block_paragraph

      def block_box(block)
        keys!(block, required: %w[type label paragraphs], optional: %w[tone])

        fail!(:invalid_value, "tone") if block.key?("tone") && !BOX_TONES.include?(block["tone"])
        text(block["label"], "label", max: SHORT_MAX)
        list(block["paragraphs"], "paragraphs", max: PARAGRAPHS_MAX)&.each { text(it, "paragraphs") }
      end

      def block_steps(block)
        keys!(block, required: %w[type items], optional: %w[label])

        text(block["label"], "label", max: SHORT_MAX) if block.key?("label")
        list(block["items"], "items", max: ITEMS_MAX)&.each { text(it, "items") }
      end

      def block_table(block)
        keys!(block, required: %w[type headers rows], optional: %w[caption])

        text(block["caption"], "caption", max: SHORT_MAX) if block.key?("caption")
        headers = list(block["headers"], "headers", max: COLUMNS_MAX)
        headers&.each { text(it, "headers", max: SHORT_MAX) }
        list(block["rows"], "rows", max: ROWS_MAX)&.each { table_row(it, headers) }
      end

      def table_row(row, headers)
        return unless list(row, "rows", max: COLUMNS_MAX)

        row.each { text(it, "rows", blank: true) }
        fail!(:wrong_size, "rows") if headers && row.size != headers.size
      end

      def block_figure(block) = kind_block(block, FIGURE_KINDS)

      def block_media(block) = kind_block(block, MEDIA_KINDS)

      def kind_block(block, kinds)
        keys!(block, required: %w[type kind], optional: %w[caption params])

        fail!(:unknown_kind, block["kind"].to_s[0, 40]) unless kinds.include?(block["kind"])
        text(block["caption"], "caption", max: SHORT_MAX) if block.key?("caption")
        params(block["params"]) if block.key?("params")
      end

      # Les réglages d'une figure : bornés, jamais du code ni un lien. Chaque kind en tire ses valeurs et les borne à son tour.
      def params(value)
        return fail!(:wrong_type, "params") unless value.is_a?(Hash)
        return fail!(:too_many, "params") if value.size > PARAMS_MAX

        value.each do |key, item|
          path = "params.#{key}"
          fail!(:invalid_value, path) unless PARAM_KEY.match?(key)
          param_value(item, path)
        end
      end

      def param_value(item, path)
        case item
        when true, false then nil
        when Numeric then number(item, path)
        when String then text(item, path, max: SHORT_MAX, blank: true, inline: false)
        else fail!(:wrong_type, path)
        end
      end

      def block_exercise(block)
        keys!(block, required: %w[type title prompt fields], optional: %w[hint correction])

        text(block["title"], "title", max: SHORT_MAX)
        text(block["prompt"], "prompt")
        %w[hint correction].each { text(block[it], it) if block.key?(it) }
        fields = list(block["fields"], "fields", max: FIELDS_MAX)
        ids = []
        fields&.each { |field| validate_field(field, ids) }
      end

      def validate_field(field, ids)
        return fail!(:wrong_type, "fields") unless field.is_a?(Hash)

        input = field["input"]
        return fail!(:invalid_value, "input") unless INPUTS.include?(input)

        extra = input == "choice" ? %w[options answer] : %w[answer]
        keys!(field, required: %w[id input label] + extra, optional: input == "choice" ? %w[frozen] : [])

        field_id(field["id"], ids)
        text(field["label"], "label", max: SHORT_MAX)
        input == "choice" ? choice_field(field) : number(field["answer"], "answer")
      end

      def field_id(id, ids)
        return fail!(:invalid_value, "id") unless id.is_a?(String) && FIELD_ID.match?(id)

        fail!(:duplicate_id, id) if ids.include?(id)
        ids << id
      end

      def choice_field(field)
        options = list(field["options"], "options", max: OPTIONS_MAX, min: OPTIONS_MIN)
        options&.each { text(it, "options", max: SHORT_MAX) }
        boolean(field["frozen"], "frozen") if field.key?("frozen")
        integer(field["answer"], "answer", 0...(options&.size || OPTIONS_MAX))
      end

      def block_practice(block)
        bank = block["kind"] == "bank"
        keys!(block, required: %w[type kind title] + (bank ? %w[bank] : []))

        fail!(:unknown_kind, block["kind"].to_s[0, 40]) unless GENERATOR_KINDS.include?(block["kind"])
        text(block["title"], "title", max: SHORT_MAX)
        list(block["bank"], "bank", max: BANK_MAX)&.each { bank_item(it) } if bank
      end

      def bank_item(item)
        return unless keys!(item, required: %w[prompt answer solution])

        text(item["prompt"], "bank.prompt")
        number(item["answer"], "bank.answer")
        text(item["solution"], "bank.solution")
      end

      def block_writing(block)
        keys!(block, required: %w[type title prompt], optional: %w[connectors min_words min_paragraphs])

        text(block["title"], "title", max: SHORT_MAX)
        text(block["prompt"], "prompt")
        list(block["connectors"], "connectors", max: CONNECTORS_MAX, min: 0)&.each { text(it, "connectors", max: SHORT_MAX) } if block.key?("connectors")
        integer(block["min_words"], "min_words", 0..WORDS_MAX) if block.key?("min_words")
        integer(block["min_paragraphs"], "min_paragraphs", 0..PARAGRAPH_COUNT_MAX) if block.key?("min_paragraphs")
      end
    end
  end
end
