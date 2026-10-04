# 🔌 INFRA · Queries::Catalog::AudienceFilter
# Rôle : la règle de ReadOwnLevelPolicy en SQL, sur `courses` : niveau d'une classe, série vide ou de cette classe
# ADR  : 0035 (amendement du 2026-10-01) · UDR : 0013 (amendement du 2026-10-01)
module Queries
  module Catalog
    module AudienceFilter
      # audience : Entities::Catalog::LevelAudience. → relation Orm::Course à fusionner (`merge`) dans une requête qui joint
      # `courses` ; aucune classe : aucun cours.
      def self.courses(audience)
        return Orm::Course.none if audience.empty?

        audience.pairs.map { |level_id, series_id| Orm::Course.where(level_id:, series_id: [ nil, series_id ].uniq) }.reduce(:or)
      end
    end
  end
end
