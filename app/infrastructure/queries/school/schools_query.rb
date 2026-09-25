# 🔌 INFRA · Queries::School::SchoolsQuery
# Rôle : liste nationale des établissements (SC-04) : filtres DRENA, type, cycle, statut et nom, 50 par page avec le total
# ADR  : 0026, 0030 · UDR : 0036
module Queries
  module School
    class SchoolsQuery
      PER_PAGE = 50
      Row = Data.define(:public_id, :name, :sigle, :drena_public_id, :drena_name, :school_type, :cycle, :status,
                        :classrooms_count, :teachers_count)
      Page = Data.define(:rows, :total_count, :page, :pages)

      # La recherche ignore casse et accents sans extension PostgreSQL : les deux côtés passent par la même table.
      ACCENTED = "àâäçéèêëîïôöùûüÿÀÂÄÇÉÈÊËÎÏÔÖÙÛÜŸ".freeze
      PLAIN = "aaaceeeeiioouuuyaaaceeeeiioouuuy".freeze
      SEARCHED = %w[schools.name schools.sigle].map { "translate(lower(#{it}), '#{ACCENTED}', '#{PLAIN}') LIKE :pattern" }
                                              .join(" OR ").freeze

      def call(drena: nil, school_type: nil, cycle: nil, status: nil, search: nil, page: 1, school_year: current_school_year)
        scope = filtered(drena:, school_type:, cycle:, status:, search:)
        total_count = scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_i.clamp(1, pages)
        rows = scope.order(:name, :id).offset((page - 1) * PER_PAGE).limit(PER_PAGE).pluck(*columns(school_year))
        Page.new(rows: rows.map { |values| Row.new(*values) }, total_count:, page:, pages:)
      end

      # → Row | nil
      def find(public_id:, school_year: current_school_year)
        values = Orm::School.joins(:drena).where(public_id:).pick(*columns(school_year))
        values && Row.new(*values)
      end

      private

      def filtered(drena:, school_type:, cycle:, status:, search:)
        scope = Orm::School.joins(:drena)
        scope = scope.where(drenas: { public_id: drena }) if drena.present?
        scope = scope.where(school_type:) if Entities::School::School::SCHOOL_TYPES.include?(school_type)
        scope = scope.where(cycle:) if Entities::School::School::CYCLES.include?(cycle)
        scope = scope.where(status:) if Entities::School::School::STATUSES.include?(status)
        term = ActiveSupport::Inflector.transliterate(search.to_s.squish).downcase
        term.empty? ? scope : scope.where(SEARCHED, pattern: "%#{Orm::School.sanitize_sql_like(term)}%")
      end

      def columns(school_year)
        [ "schools.public_id", "schools.name", "schools.sigle", "drenas.public_id", "drenas.name", "schools.school_type",
          "schools.cycle", "schools.status",
          Arel.sql(Orm::School.sanitize_sql_array([ "(SELECT COUNT(*) FROM classrooms WHERE classrooms.school_id = schools.id " \
                                                    "AND classrooms.school_year = ?)", school_year ])),
          Arel.sql("(SELECT COUNT(*) FROM teacher_schools WHERE teacher_schools.school_id = schools.id)") ]
      end

      def current_school_year = Entities::Classroom::SchoolYear.current(Date.current)
    end
  end
end
