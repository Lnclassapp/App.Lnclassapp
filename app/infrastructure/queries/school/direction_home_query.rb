# 🔌 INFRA · Queries::School::DirectionHomeQuery
# Rôle : accueil de la direction : carte « Établissement » (chiffres, alertes) et bulles « Niveaux » à taux de rendu
# ADR  : 0065 · UDR : 0072 (§3.2) · compose StudentWorkQuery et SchoolTeachersQuery ; nombre fixe de requêtes (≤ 12)
module Queries
  module School
    class DirectionHomeQuery
      Home = Data.define(:school_name, :school_type, :school_active, :school_year, :figures, :alerts, :levels)
      Figures = Data.define(:classrooms, :students, :teachers)
      # submission_rate : taux de rendu du niveau, toutes ses classes confondues ; nil → pas de pastille.
      LevelBubble = Data.define(:slug, :name, :classrooms_count, :submission_rate)

      # school_id vient toujours du compte de la direction (ADR-0065), jamais de l'adresse. → Home
      def call(school_id:, school_year: Entities::Classroom::SchoolYear.current(Date.current))
        overview = StudentWorkQuery.new.classrooms(school_id:, school_year:)
        teachers = SchoolTeachersQuery.new.call(school_id:, school_year:).teachers
        public_ids = overview.classrooms.map(&:public_id)
        school_type, status = Orm::School.where(id: school_id).pick(:school_type, :status)
        active = status == "active"

        Home.new(school_name: overview.school_name, school_type:, school_active: active, school_year:,
                 figures: Figures.new(classrooms: public_ids.size, students: students_count(public_ids), teachers: teachers.size),
                 alerts: Entities::School::DirectionAlerts.call(
                   school_active: active, classrooms: facts(overview.classrooms, teachers_by_classroom(public_ids)),
                   teachers_without_classroom: teachers.count { it.classroom_names.empty? }
                 ),
                 levels: overview.classrooms.group_by(&:level_slug).values.map { level_bubble(it) })
      end

      private

      # Un élève présent dans deux classes compte une fois (ADR-0065 §4 : adhésion non quittée, compte non anonymisé).
      def students_count(public_ids)
        Orm::User.joins(StudentWorkQuery::PRESENT)
                 .where(anonymized_at: nil, classroom_students: { classroom_id: Orm::Classroom.where(public_id: public_ids).select(:id) })
                 .distinct.count(:id)
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
