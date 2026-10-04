# 🔌 INFRA · Queries::School::DirectionHomeQuery
# Rôle : accueil de la direction : carte « Établissement » (chiffres, alertes) et bulles « Niveaux » à taux de rendu
# ADR  : 0065 (amendement du 2026-10-04 : gardé 5 minutes), 0067 · UDR : 0072 (§3.2) · compose StudentWorkQuery et SchoolTeachersQuery
module Queries
  module School
    class DirectionHomeQuery
      Home = Data.define(:school_name, :school_type, :school_active, :school_year, :figures, :alerts, :levels)
      Figures = Data.define(:classrooms, :students, :teachers)
      # submission_rate : taux de rendu du niveau, toutes ses classes confondues ; nil → pas de pastille.
      LevelBubble = Data.define(:slug, :name, :classrooms_count, :submission_rate)

      # ADR-0065, amendement du 2026-10-04 : comme l'année du pilotage (ADR-0062), l'accueil garde 5 minutes ses chiffres,
      # ses alertes et ses bulles, sans invalidation fine. CACHE_VERSION change avec une définition ou la forme de Home.
      CACHE_TTL = 5.minutes
      CACHE_VERSION = 1

      # cache : Rails.cache (Solid Cache en production) ; un test passe un NullStore pour lire en direct.
      def initialize(cache: Rails.cache)
        @cache = cache
      end

      # school_id vient toujours du compte de la direction (ADR-0065), jamais de l'adresse. Une entrée par établissement et
      # par année scolaire : rien ne dépend de l'acteur, toutes les directions d'un établissement lisent la même. → Home
      def call(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        key = [ "direction_home", "v#{CACHE_VERSION}", school_id, school_year ].join("/")
        @cache.fetch(key, expires_in: CACHE_TTL) { read(school_id, school_year) }
      end

      private

      def read(school_id, school_year)
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
                 levels: overview.classrooms.group_by(&:level_slug).values.map { level_bubble(it) })
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

      # Taux du niveau : Σ devoirs rendus × 100 / Σ (élèves × devoirs) de ses classes, jamais la moyenne de leurs taux.
      def level_bubble(rows)
        given = rows.sum { it.students_count * it.assignments_count }
        LevelBubble.new(slug: rows.first.level_slug, name: rows.first.level_name, classrooms_count: rows.size,
                        submission_rate: ((rows.sum(&:submitted_count) * 100.0 / given).round unless given.zero?))
      end
    end
  end
end
