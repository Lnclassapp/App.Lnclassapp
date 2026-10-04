# 🔌 INFRA · Queries::School::DrenaSchoolsQuery
# Rôle : pilotage sous filtre DRENA (RE-07 à RE-10) : ses établissements et leurs classes, enseignants, élèves et élèves actifs
# ADR  : 0062, 0067 · UDR : 0068 · définitions de la ligne DRENA, lues avec les chiffres de TeamDashboardQuery (même cache)
module Queries
  module School
    class DrenaSchoolsQuery
      PER_PAGE = 25
      Drena = Data.define(:public_id, :name)
      SchoolRow = Data.define(:public_id, :name, :status, :classrooms_count, :teachers_count, :students_count,
                              :active_students_count)
      Page = Data.define(:drena, :rows, :page, :pages, :total)

      COLUMNS = [ "schools.public_id", "schools.name", "schools.status",
                  "COALESCE(classroom_counts.classrooms_count, 0)", "COALESCE(teacher_counts.teachers_count, 0)",
                  "COALESCE(student_counts.students_count, 0)",
                  "COALESCE(student_counts.active_students_count, 0)" ].map { Arel.sql(it) }.freeze
      ORDER = Arel.sql("COALESCE(student_counts.students_count, 0) DESC, schools.name, schools.id")
      # Un établissement non actif reste listé tant qu'il compte quelque chose : la somme des lignes égale la ligne DRENA.
      # Un élève placé l'est dans une classe active de l'année : un établissement qui en a un a déjà une classe comptée.
      LISTED = "schools.status = 'active' OR classroom_counts.school_id IS NOT NULL " \
               "OR teacher_counts.school_id IS NOT NULL".freeze

      # Toutes les lignes de la DRENA, triées, en une requête : TeamDashboardQuery les lit avec ses chiffres, dans la même
      # entrée de cache en vue « année » (ADR-0062, amendement du 2026-10-04). since : début de la période.
      # → Array<SchoolRow>
      def rows(drena_id:, year:, since:)
        @drena_id = drena_id
        @year = year
        @since = since
        listed.joins(left_join(students_by_school, "student_counts")).order(ORDER).pluck(*COLUMNS).map { SchoolRow.new(*it) }
      end

      # drena : la DRENA de la page (public_id, name) ; rows : ses lignes (#rows) ; search, page : textes de l'URL. Une page
      # invalide vaut 1, trop grande la dernière. Aucune requête sans recherche. → Page
      def page(drena:, rows:, search: nil, page: 1)
        rows = matching(rows, search)
        pages = [ rows.size.fdiv(PER_PAGE).ceil, 1 ].max
        page = page.to_s.to_i.clamp(1, pages) # to_s : school_page[]=2 donne un tableau
        Page.new(drena: Drena.new(public_id: drena.public_id, name: drena.name), rows: rows.slice((page - 1) * PER_PAGE, PER_PAGE),
                 page:, pages:, total: rows.size)
      end

      private

      # La recherche garde sa définition (TextSearch sur le nom, en SQL, une requête) ; elle filtre les lignes lues, dans
      # leur ordre : un établissement créé ou renommé depuis apparaît avec les chiffres suivants.
      def matching(rows, search)
        return rows if Queries::Shared::TextSearch.normalize(search).empty?

        found = Queries::Shared::TextSearch.apply(Orm::School.where(public_id: rows.map(&:public_id)), search, columns: [ "schools.name" ])
                                           .pluck(:public_id).to_set
        rows.select { found.include?(it.public_id) }
      end

      def listed
        Orm::School.where(drena_id: @drena_id)
                   .joins(left_join(classrooms_by_school, "classroom_counts"))
                   .joins(left_join(teachers_by_school, "teacher_counts"))
                   .where(LISTED)
      end

      def left_join(relation, name) = "LEFT JOIN (#{relation.to_sql}) #{name} ON #{name}.school_id = schools.id"

      # Les définitions de TeamDashboardQuery, lues sur la seule DRENA et groupées par établissement (ADR-0062, amendement
      # du 2026-10-03) : une définition qui change, change dans les deux lectures (RE-08, testé).

      # Classes actives de l'année scolaire.
      def classrooms_by_school
        Orm::Classroom.joins(:school).where(status: "active", school_year: @year, schools: { drena_id: @drena_id })
                      .group("classrooms.school_id").select("classrooms.school_id", "COUNT(*) AS classrooms_count")
      end

      # Enseignants rattachés à titre principal, non anonymisés (ADR-0030).
      def teachers_by_school
        Orm::TeacherSchool.joins(:teacher, :school).where(primary: true, users: { anonymized_at: nil }, schools: { drena_id: @drena_id })
                          .group("teacher_schools.school_id").select("teacher_schools.school_id", "COUNT(*) AS teachers_count")
      end

      # Élèves placés : classe principale, non quittée, active, de l'année (ADR-0040, ADR-0041) ; actifs : au moins une
      # session commencée dans la période.
      def students_by_school
        started = Orm::ExerciseSession.where(started_at: @since..).select(:student_id).to_sql
        Orm::ClassroomStudent.joins(:student, classroom: :school)
                             .where(primary: true, left_at: nil, users: { anonymized_at: nil },
                                    classrooms: { status: "active", school_year: @year }, schools: { drena_id: @drena_id })
                             .group("classrooms.school_id")
                             .select("classrooms.school_id", "COUNT(*) AS students_count",
                                     "COUNT(*) FILTER (WHERE classroom_students.student_id IN (#{started})) AS active_students_count")
      end
    end
  end
end
