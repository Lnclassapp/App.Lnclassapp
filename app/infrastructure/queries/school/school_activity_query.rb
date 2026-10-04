# 🔌 INFRA · Queries::School::SchoolActivityQuery
# Rôle : « Activité récente » de la direction : devoirs donnés, élèves arrivés, enseignants arrivés, sur 30 jours (AD-17, AD-18)
# ADR  : 0065 · UDR : 0072 §3.11 · lue dans les tables métier datées, jamais dans le journal d'audit ; trois requêtes
module Queries
  module School
    class SchoolActivityQuery
      LIMIT = 10
      WINDOW = 30.days
      # kind : :assignment, :student_joined ou :teacher_joined ; les champs sans objet pour un type valent nil. Un enseignant
      # anonymisé ne livre ni son genre ni son nom ; d'un élève, seuls le prénom et l'initiale du nom sortent (memo Q10).
      Event = Data.define(:kind, :at, :teacher_gender, :teacher_last_name, :teacher_anonymized, :student_first_name,
                          :student_last_initial, :exercise_title, :classroom_name, :classroom_public_id)
      BLANK = Event.members.to_h { [ it, nil ] }.freeze
      CLASSROOM_COLUMNS = %w[classrooms.name classrooms.public_id].freeze

      # school_id vient toujours du compte de la direction (ADR-0065). Une requête par type, chacune réduite à ses 10
      # plus récents, puis la fusion : les 10 plus récents de tous, du plus récent au plus ancien. → [Event]
      def call(school_id:, now:, school_year: Entities::Classroom::SchoolYear.current(now.to_date))
        window = (now - WINDOW)..now
        events = assignments(school_id, school_year, window) + students_joined(school_id, school_year, window) +
                 teachers_joined(school_id, window)
        events.sort_by.with_index { |event, index| [ -event.at.to_r, index ] }.first(LIMIT)
      end

      private

      # Un devoir reste donné même archivé (retrait de son enseignant) : comme les chiffres de StudentWorkQuery.
      def assignments(school_id, school_year, window)
        in_classrooms(Orm::ClassroomAssignment, school_id, school_year)
          .joins(:assigned_by).joins("JOIN exercises ON exercises.id = classroom_assignments.assignable_id")
          .where(assignable_type: "Exercise", assigned_at: window).order(assigned_at: :desc, id: :desc).limit(LIMIT)
          .pluck(:assigned_at, "users.gender", "users.last_name", "users.anonymized_at", "exercises.title", *CLASSROOM_COLUMNS)
          .map do |at, gender, last_name, anonymized_at, exercise_title, classroom_name, classroom_public_id|
            event(kind: :assignment, at:, **teacher(gender, last_name, anonymized_at), exercise_title:, classroom_name:,
                  classroom_public_id:)
          end
      end

      # Un élève anonymisé disparaît de l'activité.
      def students_joined(school_id, school_year, window)
        in_classrooms(Orm::ClassroomStudent, school_id, school_year)
          .joins(:student).where(joined_at: window, users: { anonymized_at: nil })
          .order(joined_at: :desc, id: :desc).limit(LIMIT)
          .pluck(:joined_at, "users.first_name", "users.last_name", *CLASSROOM_COLUMNS)
          .map do |at, student_first_name, last_name, classroom_name, classroom_public_id|
            event(kind: :student_joined, at:, student_first_name:, student_last_initial: last_name.first.upcase, classroom_name:,
                  classroom_public_id:)
          end
      end

      # Un enseignant en attente n'a pas de rattachement (ADR-0063), un enseignant anonymisé disparaît.
      def teachers_joined(school_id, window)
        Orm::TeacherSchool.joins(:teacher).where(school_id:, created_at: window, users: { anonymized_at: nil })
                          .order(created_at: :desc, id: :desc).limit(LIMIT)
                          .pluck(:created_at, "users.gender", "users.last_name")
                          .map { |at, gender, last_name| event(kind: :teacher_joined, at:, **teacher(gender, last_name, nil)) }
      end

      def in_classrooms(scope, school_id, school_year)
        scope.joins(:classroom).where(classrooms: { school_id:, school_year:, status: "active" })
      end

      def teacher(gender, last_name, anonymized_at)
        return { teacher_anonymized: true } if anonymized_at

        { teacher_gender: gender, teacher_last_name: last_name, teacher_anonymized: false }
      end

      def event(**fields) = Event.new(**BLANK, **fields)
    end
  end
end
