# 🧠 DOMAINE · Policies::Catalog::ReadOwnLevelPolicy
# Rôle : un élève ne lit que les cours de son niveau (et de sa série, ou communs) ; les autres rôles, tous
# ADR  : 0028, 0035 (amendement du 2026-10-01) · UDR : 0013 (amendement du 2026-10-01)
module Policies
  module Catalog
    class ReadOwnLevelPolicy
      # audience : Entities::Catalog::LevelAudience de l'élève ; course_level : { level_id:, series_id: } du cours lu
      # (celui de la fiche ou de l'exercice). Hors niveau : :not_found, comme un brouillon, sans rien confirmer.
      def call(actor:, audience:, course_level:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success unless actor.student?
        return Shared::Result.success if audience.covers?(**course_level)

        Shared::Result.failure(:not_found)
      end
    end
  end
end
