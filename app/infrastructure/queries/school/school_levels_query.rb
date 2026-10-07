# 🔌 INFRA · Queries::School::SchoolLevelsQuery
# Rôle : niveaux de la cascade élève : ceux où un établissement actif a une classe active de l'année ; le nom, rien d'autre
# ADR  : 0062, 0083 · UDR : 0079
module Queries
  module School
    class SchoolLevelsQuery
      Row = Data.define(:slug, :name)

      # Lecture publique, sans use case (ADR-0062) : ni classe, ni effectif, ni enseignant. Établissement inconnu, en
      # brouillon ou désactivé → []. → [Row], dans l'ordre du référentiel
      def call(school_public_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        level_ids = Orm::Classroom.joins(:school)
                                  .where(schools: { public_id: school_public_id, status: "active" }, status: "active", school_year:)
                                  .select(:level_id)
        Orm::Level.where(id: level_ids).order(:position).pluck(:slug, :name).map { Row.new(*it) }
      end
    end
  end
end
