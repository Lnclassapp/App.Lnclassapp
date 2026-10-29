# 🧠 DOMAINE · Entities::Catalog::StatementBlocks
# Rôle : valide le sujet en blocs d'un exercice (paragraph, box, table ; dix au plus), lu comme un fichier hostile
# ADR  : 0115 (menace I9), XXXX-fiche-de-revision-par-notion-et-figures-parametrees (§4.5)
module Entities
  module Catalog
    class StatementBlocks
      # position : 1 pour le premier bloc, nil quand l'erreur porte sur la liste entière. detail : la clé ou le type en cause.
      Error = Data.define(:position, :reason, :detail)

      TYPES = %w[paragraph box table].freeze
      MAX = 10
      BOX_TONES = %w[property remember method].freeze
      SIZE_MAX = 1024 * 1024
      PARAGRAPHS_MAX = 10
      ROWS_MAX = 30
      COLUMNS_MAX = 8
      TEXT_MAX = 2000
      SHORT_MAX = 200
      # Aucun lien sortant ni ressource distante. « (MN) // (BC) » s'écrit librement : seul « :// » est un schéma.
      URL = %r{://|www\.|mailto:|javascript:|data:}i

      # nil ou [] : pas de sujet en blocs. → [Error]
      def self.errors(blocks)
        return [] if blocks.nil? || blocks == []
        return [ Error.new(position: nil, reason: :wrong_type, detail: "statement_blocks") ] unless blocks.is_a?(Array) && blocks.all?(Hash)
        return [ Error.new(position: nil, reason: :too_many, detail: "statement_blocks") ] if blocks.size > MAX

        unknown = blocks.each_with_index.filter_map do |block, index|
          type = block["type"]
          Error.new(position: index + 1, reason: :unknown_type, detail: type.to_s[0, 40]) unless TYPES.include?(type)
        end
        return unknown if unknown.any?

        new(blocks).errors
      end

      def initialize(blocks)
        @blocks = deep_stringify(blocks)
        @found = []
        @position = nil
      end

      def errors
        size = serialized_size
        return [ Error.new(position: nil, reason: :wrong_type, detail: "json") ] if size.nil?
        return [ Error.new(position: nil, reason: :too_large, detail: "statement_blocks") ] if size > SIZE_MAX

        @blocks.each_with_index do |block, index|
          @position = index + 1
          send(:"block_#{block['type']}", block)
        end
        @found
      end

      private

      def deep_stringify(value)
        case value
        when Hash then value.to_h { |key, item| [ key.to_s, deep_stringify(item) ] }
        when Array then value.map { deep_stringify(it) }
        else value
        end
      end

      def serialized_size
        JSON.generate(@blocks).bytesize
      rescue JSON::GeneratorError
        nil
      end

      def fail!(reason, detail = nil)
        @found << Error.new(position: @position, reason:, detail:)
        nil
      end

      def keys!(value, required:, optional: [])
        (value.keys - required - optional).each { fail!(:unknown_key, it) }
        (required - value.keys).each { fail!(:missing_key, it) }
        value
      end

      def list(value, key, max:)
        return fail!(:wrong_type, key) unless value.is_a?(Array)
        return fail!(:blank, key) if value.empty?
        return fail!(:too_many, key) if value.size > max

        value
      end

      # Une chaîne : bornée, sans HTML, sans URL ; les formules `$…$` doivent être équilibrées.
      def text(value, key, max: TEXT_MAX, blank: false)
        return fail!(:wrong_type, key) unless value.is_a?(String)
        return fail!(:blank, key) if !blank && value.strip.empty?
        return fail!(:too_long, key) if value.length > max
        return fail!(:html_forbidden, key) if value.include?("<")
        return fail!(:url_forbidden, key) if value.match?(URL)
        return fail!(:malformed_mark, key) if value.include?("[[") || value.include?("]]")

        fail!(:unbalanced_math, key) if value.gsub("\\$", "").count("$").odd?
      end

      def block_paragraph(block)
        keys!(block, required: %w[type text])
        text(block["text"], "text")
      end

      def block_box(block)
        keys!(block, required: %w[type label paragraphs], optional: %w[tone])

        fail!(:invalid_value, "tone") if block.key?("tone") && !BOX_TONES.include?(block["tone"])
        text(block["label"], "label", max: SHORT_MAX)
        list(block["paragraphs"], "paragraphs", max: PARAGRAPHS_MAX)&.each { text(it, "paragraphs") }
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
    end
  end
end
