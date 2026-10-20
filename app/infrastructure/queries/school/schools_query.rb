# 🔌 INFRA · Queries::School::SchoolsQuery
# Rôle : liste nationale des établissements (SC-04) : filtres DRENA, type, cycle, statut, nom ou sigle (IE-21), 50 par page
# ADR  : 0026, 0030, 0057, 0063, 0083, 0088, 0096 · UDR : 0036, 0044, 0050, 0079, 0106 · filtres : Orm::School.list_filtered
module Queries
  module School
    class SchoolsQuery
      PER_PAGE = 50
      Row = Data.define(:public_id, :name, :sigle, :drena_public_id, :drena_name, :school_type, :cycle, :status,
                        :classrooms_count, :teachers_count, :school_code, :national_code, :team_invite_token,
                        :school_code_rotated_at)
      Page = Data.define(:rows, :total_count, :page, :pages)
      # La recherche vit dans le scope partagé (ADR-0096 §4.5) ; ces noms restent lus par la recherche de comptes.
      ACCENTED = Orm::School::ACCENTED
      PLAIN = Orm::School::PLAIN
      SEARCHED = Orm::School::SEARCHED

      def call(drena: nil, school_type: nil, cycle: nil, status: nil, search: nil, page: 1, school_year: current_school_year)
        scope = Orm::School.list_filtered(drena:, school_type:, cycle:, status:, search:)
        total_count = scope.count
        pages = [ total_count.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages) # to_s : page[]=2 ou page[a]=1 donnent un tableau ou un hash
        rows = scope.order(:name, :id).offset((page - 1) * PER_PAGE).limit(PER_PAGE).pluck(*columns(school_year))
        Page.new(rows: rows.map { |values| Row.new(*values) }, total_count:, page:, pages:)
      end

      # → Row | nil
      def find(public_id:, school_year: current_school_year)
        values = Orm::School.joins(:drena).where(public_id:).pick(*columns(school_year))
        values && Row.new(*values)
      end

      private

      def columns(school_year)
        [ "schools.public_id", "schools.name", "schools.sigle", "drenas.public_id", "drenas.name", "schools.school_type",
          "schools.cycle", "schools.status",
          Arel.sql(Orm::School.sanitize_sql_array([ "(SELECT COUNT(*) FROM classrooms WHERE classrooms.school_id = schools.id " \
                                                    "AND classrooms.school_year = ? AND classrooms.status = 'active')", school_year ])),
          Arel.sql("(SELECT COUNT(*) FROM teacher_schools WHERE teacher_schools.school_id = schools.id)"), "schools.school_code",
          "schools.national_code", "schools.team_invite_token", "schools.school_code_rotated_at" ]
      end

      def current_school_year = Entities::Classroom::SchoolYear.current(Date.current)
    end
  end
end
