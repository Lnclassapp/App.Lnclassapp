# 🔌 INFRA · Repositories::Catalog::ImportSchemaValidator
# Rôle : valide un document d'import par son schéma JSON versionné (json_schemer) ; erreurs au chemin JSON du rapport
# ADR  : 0039
module Repositories
  module Catalog
    class ImportSchemaValidator
      include Ports::Catalog::ImportSchemaPort

      attr_reader :root

      # root : dossier des schémas <format>.v<version>.json, injectable pour les tests.
      def initialize(root: Rails.root.join("config/schemas"))
        @root = Pathname(root)
        @schemas = {}
      end

      def validate(format:, version:, document:)
        schema_for(format, version).validate(document).flat_map { |error| import_errors_of(error) }
      end

      # « /schools/12/type » → « schools[12].type » ; la racine du document est « $ ».
      def self.json_path(pointer)
        segments = pointer.split("/").drop(1).map { |segment| segment.gsub("~1", "/").gsub("~0", "~") }
        path = segments.each_with_object(+"") do |segment, result|
          result << (segment.match?(/\A\d+\z/) ? "[#{segment}]" : ".#{segment}")
        end
        path.empty? ? "$" : path.delete_prefix(".")
      end

      private

      def schema_for(format, version)
        @schemas[[ format, version ]] ||= JSONSchemer.schema(root.join("#{format}.v#{version}.json"))
      end

      # Une clé obligatoire absente est notée au chemin de la clé, pas à celui de son objet.
      def import_errors_of(error)
        path = self.class.json_path(error["data_pointer"])
        missing = error.dig("details", "missing_keys")
        return [ schema_error(path, error["type"]) ] if missing.nil?

        missing.map { |key| schema_error(path == "$" ? key : "#{path}.#{key}", error["type"]) }
      end

      def schema_error(path, keyword) = Entities::Catalog::ImportError.new(path:, code: "schema", params: { keyword: })
    end
  end
end
