# 🧠 DOMAINE · Entities::Catalog::LevelAudience
# Rôle : les niveaux (niveau, série) des classes actives d'un élève pour l'année ; un cours sans série vaut pour toutes
# ADR  : 0035 (amendement du 2026-10-01) · UDR : 0013 (amendement du 2026-10-01)
module Entities
  module Catalog
    LevelAudience = Data.define(:pairs) do
      # pairs : [[level_id, series_id | nil], ...], une paire par classe active de l'année.
      def initialize(pairs:)
        super(pairs: pairs.uniq.freeze)
      end

      def self.none = new(pairs: [])

      def empty? = pairs.empty?

      # Le cours est du niveau d'une classe, et sans série (commun à toutes) ou de la série de cette classe.
      def covers?(level_id:, series_id:)
        pairs.any? { |level, series| level == level_id && (series_id.nil? || series_id == series) }
      end
    end
  end
end
