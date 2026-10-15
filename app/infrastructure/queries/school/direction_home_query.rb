# 🔌 INFRA · Queries::School::DirectionHomeQuery
# Rôle : accueil de la direction : carte « Établissement » (chiffres, alertes) et bulles « Niveaux » à taux de rendu
# ADR  : 0065 (amendement du 2026-10-04 : gardé 5 minutes), 0067, 0089 (§4.2) · UDR : 0074 (§3.2), 0084 (§3.7) · compose StudentWorkQuery et SchoolTeachersQuery
module Queries
  module School
    class DirectionHomeQuery
      Home = Data.define(:school_name, :school_type, :school_active, :school_year, :figures, :alerts, :levels)
      Figures = Data.define(:classrooms, :students, :teachers)
      # submission_rate : taux de rendu du niveau, toutes ses classes confondues ; nil → pas de pastille.
      # self_practice_count : sessions « fait seul » des 7 derniers jours de ses élèves présents (ADR-0089 §4.2), 0 sans aucune.
      LevelBubble = Data.define(:slug, :name, :classrooms_count, :submission_rate, :self_practice_count)

      # ADR-0065, amendement du 2026-10-04 : comme l'année du pilotage (ADR-0062), l'accueil garde 5 minutes ses chiffres,
      # ses alertes et ses bulles, sans invalidation fine. CACHE_VERSION change avec une définition ou la forme de Home.
      CACHE_TTL = 5.minutes
      CACHE_VERSION = 2

      # cache : Rails.cache (Solid Cache en production) ; un test passe un NullStore pour lire en direct.
      def initialize(cache: Rails.cache)
        @cache = cache
      end

      # school_id vient toujours du compte de la direction (ADR-0065), jamais de l'adresse. Une entrée par établissement et
      # par année scolaire : rien ne dépend de l'acteur, toutes les directions d'un établissement lisent la même. today : la
      # date d'Abidjan qui clôt la fenêtre de « fait seul » ; elle entre dans la clé, l'entrée de la veille ne sert pas. → Home
      def call(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current), today: Time.zone.today)
        key = [ "direction_home", "v#{CACHE_VERSION}", school_id, school_year, today.iso8601 ].join("/")
        @cache.fetch(key, expires_in: CACHE_TTL) { read(school_id, school_year, today) }
      end

      private

      def read(school_id, school_year, today)
        overview = StudentWorkQuery.new.classrooms(school_id:, school_year:)
        teachers = SchoolTeachersQuery.new.call(school_id:, school_year:).teachers
        public_ids = overview.classrooms.map(&:public_id)
        school_type, status = Orm::School.where(id: school_id).pick(:school_type, :status)
        active = status == "active"

        Home.new(school_name: overview.school_name, school_type:, school_active: active, school_year:,
                 figures: Figures.new(classrooms: public_ids.size, students: overview.students_count, teachers: teachers.size),
                 alerts: Entities::School::DirectionAlerts.call(
                   school_active: active, classrooms: facts(overview.classrooms, teachers_by_classroom(public_ids)),
                   teachers_without_classroom: teachers.count { it.classroom_names.empty? }
                 ),
                 levels: level_bubbles(overview.classrooms, self_practice_by_level(school_id, school_year, today)))
      end

      # { public_id => enseignants déclarés } ; un compte anonymisé n'enseigne plus (il n'est pas sur la page « Enseignants »).
      def teachers_by_classroom(public_ids)
        Orm::TeacherClassroom.joins(:classroom, :teacher).where(classrooms: { public_id: public_ids }, users: { anonymized_at: nil })
                             .group("classrooms.public_id").count
      end

      def facts(rows, teachers)
        rows.map do |row|
          Entities::School::DirectionAlerts::ClassroomFacts.new(name: row.name, students_count: row.students_count,
                                                                teachers_count: teachers.fetch(row.public_id, 0),
                                                                submission_rate: row.submission_rate)
        end
      end

      # ADR-0089 §4.2 : { slug du niveau => sessions « fait seul » } en une requête. Un élève présent (adhésion non quittée,
      # compte non anonymisé, ADR-0065 §4) d'une classe active de l'année et de l'établissement ; une session compte une fois
      # par niveau, même si son élève est dans deux classes de ce niveau.
      def self_practice_by_level(school_id, school_year, today)
        Queries::Classroom::ClassroomOverviewQuery.self_practice(today)
          .joins("JOIN users ON users.id = exercise_sessions.student_id AND users.anonymized_at IS NULL")
          .joins("JOIN classroom_students ON classroom_students.student_id = exercise_sessions.student_id " \
                 "AND classroom_students.left_at IS NULL")
          .joins("JOIN classrooms ON classrooms.id = classroom_students.classroom_id JOIN levels ON levels.id = classrooms.level_id")
          .where(classrooms: { school_id:, school_year:, status: "active" })
          .group("levels.slug").distinct.count(:id)
      end

      # Taux du niveau : Σ devoirs rendus × 100 / Σ (élèves × devoirs) de ses classes, jamais la moyenne de leurs taux.
      def level_bubbles(classrooms, self_practice)
        classrooms.group_by(&:level_slug).values.map do |rows|
          given = rows.sum { it.students_count * it.assignments_count }
          LevelBubble.new(slug: rows.first.level_slug, name: rows.first.level_name, classrooms_count: rows.size,
                          submission_rate: ((rows.sum(&:submitted_count) * 100.0 / given).round unless given.zero?),
                          self_practice_count: self_practice.fetch(rows.first.level_slug, 0))
        end
      end
    end
  end
end
