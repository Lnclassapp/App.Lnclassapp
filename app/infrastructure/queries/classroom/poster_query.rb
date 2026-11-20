# 🔌 INFRA · Queries::Classroom::PosterQuery
# Rôle : ce que l'affiche A4 d'une classe porte (classe, établissement, jeton du lien), et le kit des classes ouvertes de l'année d'un établissement
# ADR  : partage-classe-k-factor · UDR : partage-de-classe (§3.2)
module Queries
  module Classroom
    class PosterQuery
      Poster = Data.define(:classroom_name, :school_name, :link_token)

      COLUMNS = [ "classrooms.name", "schools.name", "classrooms.link_token" ].freeze

      # → Poster | nil
      def for_classroom(public_id:)
        row = scope.where(classrooms: { public_id: }).pick(*COLUMNS)
        row && Poster.new(*row)
      end

      # Classes ouvertes de l'année en cours, par niveau puis nom (ordre naturel : « 6e 2 » avant « 6e 10 »).
      # → [Poster]
      def for_school(school_id:, today: Date.current)
        scope.where(classrooms: { school_id:, status: "active", school_year: Entities::Classroom::SchoolYear.current(today) })
             .pluck("levels.position", *COLUMNS)
             .sort_by { |position, name, *| [ position, natural_key(name) ] }
             .map { |_, *row| Poster.new(*row) }
      end

      private

      def scope = Orm::Classroom.joins(:level, :school)

      def natural_key(name) = name.scan(/\d+|\D+/).map { it.match?(/\A\d+\z/) ? [ 0, it.to_i, "" ] : [ 1, 0, it ] }
    end
  end
end
