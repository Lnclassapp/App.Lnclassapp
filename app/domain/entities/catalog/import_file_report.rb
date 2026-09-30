# 🧠 DOMAINE · Entities::Catalog::ImportFileReport
# Rôle : bilan d'un fichier dans un rapport d'import : nom d'affichage, taille, lu ou refusé, et ses propres compteurs
# ADR  : 0068 · UDR : 0055
module Entities
  module Catalog
    # status : pending (pas encore traité), read (lu, ses éléments sont comptés) ou rejected (refusé, motif dans reason).
    ImportFileReport = Data.define(:name, :byte_size, :status, :reason, :imported, :skipped, :errors) do
      def initialize(name:, byte_size:, status: "pending", reason: nil, imported: 0, skipped: 0, errors: 0)
        raise ArgumentError, "statut de fichier inconnu : #{status.inspect}" unless ImportFileReport::STATUSES.include?(status)

        super
      end

      def rejected? = status == "rejected"

      # Deux fichiers du même nom, pris dans deux dossiers, restent distincts : « cours.json », « cours.json (2) ».
      def self.display_names(names)
        seen = Hash.new(0)
        names.map { |name| (seen[name] += 1) == 1 ? name : "#{name} (#{seen[name]})" }
      end
    end
    ImportFileReport::STATUSES = %w[pending read rejected].freeze
  end
end
