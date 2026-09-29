# 🔌 INFRA · Queries::Shared::TextSearch
# Rôle : fragment de recherche par nom, sans casse ni accents, commun aux listes cherchées pendant la frappe
# ADR  : 0026 · UDR : 0054 (§3.9) · sans extension PostgreSQL ni index : les deux côtés passent par la même table
module Queries
  module Shared
    module TextSearch
      ACCENTED = "àâäçéèêëîïôöùûüÿÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ".freeze
      PLAIN = "aaaceeeeiioouuuyaaaceeeeiioouuuy".freeze

      module_function

      # → la portée filtrée sur `columns` (expressions SQL écrites par le code, jamais par l'utilisateur), ou la même
      # portée quand le terme est vide. Les jokers de LIKE tapés par la personne sont cherchés tels quels.
      def apply(scope, term, columns:)
        term = normalize(term)
        return scope if term.empty?

        condition = columns.map { "translate(lower(#{it}), '#{ACCENTED}', '#{PLAIN}') LIKE :pattern" }.join(" OR ")
        scope.where(condition, pattern: "%#{ActiveRecord::Base.sanitize_sql_like(term)}%")
      end

      # Le côté Ruby du même traitement : espaces réduits, minuscules, accents retirés.
      def normalize(term)
        ActiveSupport::Inflector.transliterate(term.to_s.squish).downcase
      end
    end
  end
end
