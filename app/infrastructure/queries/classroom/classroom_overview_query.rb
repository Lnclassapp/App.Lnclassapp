# 🔌 INFRA · Queries::Classroom::ClassroomOverviewQuery
# Rôle : corps de la page d'une classe (CL-10) : jours de séance de l'enseignant, exercices assignés et leurs comptes, cours, élèves au numéro masqué
# ADR  : 0026, 0028, 0048, 0060, 0062, 0072, 0079, 0082 (§4.4 bis) · UDR : 0027, 0047, 0054, 0062 (§3.4), 0072 (§3.4), 0078 (§3.8 ter)
module Queries
  module Classroom
    class ClassroomOverviewQuery
      # students : nil sans show_roster (ReadClassroomPolicy) — la liste nominative n'est alors même pas lue.
      # session_days : jours (1 = lundi … 6 = samedi) de l'enseignant pour la classe, [] s'il ne les a pas renseignés ;
      # nil sans teacher_id (l'équipe n'a pas de jours, ADR-0072 §4.2).
      Overview = Data.define(:students, :session_days, :assignments, :courses)
      # last_session_public_id : la dernière session terminée, dont l'enseignant ouvre le résultat ; nil sans session.
      # photo_version : nil sans photo (ADR-0060).
      # contact : toujours masqué (« 07 •• •• •• 04 »), pour tout lecteur ; le numéro complet ne quitte pas cette requête
      # (ADR-0082 §4.4 bis : protéger les élèves).
      StudentRow = Data.define(:public_id, :display_name, :contact, :last_score_percent, :last_session_public_id, :photo_version)
      # counts : AssignmentFollowUpQuery::Counts, nil sans show_follow_up (FollowAssignmentPolicy, ADR-0072 §4.5).
      # comprehension : Assessment::ComprehensionSummaryQuery::Summary (ADR-0079), nil sans show_follow_up, comme counts.
      AssignmentRow = Data.define(:public_id, :exercise_title, :material_name, :material_category, :due_on, :counts,
                                  :comprehension)
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category,
                              :essentials_count)

      STUDENT_COLUMNS = %w[users.id users.public_id users.first_name users.last_name users.contact].freeze
      # « Awa Bamba » se trouve par « awa », « bamba » ou « awa bamba » (UDR-0054 §3.9).
      STUDENT_NAME = "concat_ws(' ', users.first_name, users.last_name)".freeze
      ASSIGNMENT_COLUMNS = %w[classroom_assignments.id classroom_assignments.public_id exercises.title materials.name
                              materials.category classroom_assignments.due_on].freeze
      COURSE_COLUMNS = %w[courses.id courses.slug courses.name courses.subtitle levels.name series.name materials.name
                          materials.category].freeze

      # search : « Chercher un élève » ; vide ou nil → toute la liste. Il ne filtre que les élèves de cette classe.
      # teacher_id : l'enseignant qui regarde (ses jours, sa matière) ; nil pour l'équipe, qui voit toutes les matières.
      # → Overview | nil
      def call(public_id:, show_roster:, search: nil, teacher_id: nil, show_follow_up: false)
        id, level_id, series_id = Orm::Classroom.where(public_id:).pick(:id, :level_id, :series_id)
        return if id.nil?

        Overview.new(students: (students(id, search) if show_roster), session_days: (session_days(teacher_id, id) if teacher_id),
                     assignments: assignments(id, show_follow_up), courses: courses(level_id, series_id, teacher_id))
      end

      private

      def students(classroom_id, search)
        scope = Orm::ClassroomStudent.joins(:student).where(classroom_id:, left_at: nil)
        rows = Queries::Shared::TextSearch.apply(scope, search, columns: [ STUDENT_NAME ])
                                          .order("users.last_name", "users.first_name").pluck(*STUDENT_COLUMNS)
        sessions = last_sessions(rows.map(&:first))
        photos = Queries::Identity::PhotoVersions.for(user_ids: rows.map(&:first))

        rows.map do |id, public_id, first_name, last_name, contact|
          score, session_public_id = sessions[id]
          StudentRow.new(public_id:, display_name: "#{first_name} #{last_name}", contact: Entities::Identity::Contact.mask(contact),
                         last_score_percent: score, last_session_public_id: session_public_id, photo_version: photos[id])
        end
      end

      # { student_id => [score, public_id] } de la dernière session terminée de chaque élève, en une requête.
      def last_sessions(student_ids)
        Orm::ExerciseSession.where(student_id: student_ids, status: "completed").order(:student_id, completed_at: :desc)
                            .pluck(Arel.sql("DISTINCT ON (student_id) student_id"), :score_percent, :public_id)
                            .to_h { |id, score, public_id| [ id, [ score, public_id ] ] }
      end

      def session_days(teacher_id, classroom_id)
        Orm::ClassroomSessionDay.where(teacher_id:, classroom_id:).order(:weekday).pluck(:weekday)
      end

      # UDR-0062 §3.4 : par échéance croissante, sans échéance à la fin, puis du plus récent au plus ancien.
      def assignments(classroom_id, show_follow_up)
        rows = Orm::ClassroomAssignment.joins(AssignmentFollowUpQuery::EXERCISE).where(classroom_id:, status: "active")
                                       .order(Arel.sql("classroom_assignments.due_on ASC NULLS LAST"),
                                              assigned_at: :desc, id: :desc)
                                       .pluck(*ASSIGNMENT_COLUMNS)
        counts, comprehension = show_follow_up ? follow_up(classroom_id, rows.map(&:first)) : [ {}, {} ]
        rows.map do |id, public_id, exercise_title, material_name, material_category, due_on|
          AssignmentRow.new(public_id:, exercise_title:, material_name:, material_category:, due_on:, counts: counts[id],
                            comprehension: comprehension[id])
        end
      end

      # Comptes et résumé de compréhension de toutes les assignations, en un nombre de requêtes constant (ADR-0079).
      def follow_up(classroom_id, assignment_ids)
        [ AssignmentFollowUpQuery.counts(classroom_id:, assignment_ids:),
          Queries::Assessment::ComprehensionSummaryQuery.for(classroom_id:, assignment_ids:) ]
      end

      # Bloc « Cours » (UDR-0062 §3.4, memo Q18) : le chemin de l'enseignant vers les exercices. La règle d'AudienceFilter
      # (niveau de la classe, série vide ou la sienne), réduite à la matière de l'enseignant.
      def courses(level_id, series_id, teacher_id)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
                           .where(status: "published", level_id:, series_id: [ nil, series_id ].uniq)
        scope = scope.where(material_id: Orm::TeacherProfile.where(user_id: teacher_id).select(:material_id)) if teacher_id
        rows = scope.order("materials.name", "courses.name", "courses.id").pluck(*COURSE_COLUMNS)
        essentials = Orm::Essential.where(course_id: rows.map(&:first), status: "published").group(:course_id).count
        rows.map do |id, slug, name, subtitle, level_name, series_name, material_name, material_category|
          CourseRow.new(slug:, name:, subtitle:, level_name:, series_name:, material_name:, material_category:,
                        essentials_count: essentials.fetch(id, 0))
        end
      end
    end
  end
end
