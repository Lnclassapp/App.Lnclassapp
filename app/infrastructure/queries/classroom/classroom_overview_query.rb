# 🔌 INFRA · Queries::Classroom::ClassroomOverviewQuery
# Rôle : corps de la page d'une classe (CL-10) : jours de séance de l'enseignant, exercices assignés et leurs comptes, cours, élèves par note sur 20 puis par trente, au numéro masqué
# ADR  : 0026, 0028, 0048, 0060, 0062, 0072, 0079, 0083 (§4.4 bis), 0085, 0089 (§4.2), 0097 (§4.7) · UDR : 0027, 0047, 0054, 0062 (§3.4), 0072 (§3.4), 0079 (§3.8 ter), 0081 (§3.7), 0084 (§3.7), 0108
module Queries
  module Classroom
    class ClassroomOverviewQuery
      # students : nil sans show_roster (ReadClassroomPolicy) — la liste nominative n'est alors même pas lue.
      # grade_counts : { clé de Entities::Classroom::RosterGrade::KEYS => nombre d'élèves présents }, toute la classe ;
      # grade_group : le groupe de note lu (décision du porteur du 2026-10-16), nil quand une recherche porte sur toute la classe.
      # students_total : les élèves du groupe, ou ceux qui répondent à la recherche, dont students ne rend que les
      # page × PER_PAGE premiers (ADR-0097 §4.7). Les trois : nil sans show_roster.
      # new_students_count : les nouveaux de toute la classe, quelle que soit la recherche ; nil sans show_roster.
      # session_days : jours (1 = lundi … 6 = samedi) de l'enseignant pour la classe, [] s'il ne les a pas renseignés ;
      # nil sans teacher_id (l'équipe n'a pas de jours, ADR-0072 §4.2).
      Overview = Data.define(:students, :students_total, :grade_group, :grade_counts, :new_students_count, :session_days,
                             :assignments, :courses)
      # last_session_public_id : la dernière session terminée, dont l'enseignant ouvre le résultat ; nil sans session.
      # photo_version : nil sans photo (ADR-0060).
      # contact : toujours masqué (« 07 •• •• •• 04 »), pour tout lecteur ; le numéro complet ne quitte pas cette requête
      # (ADR-0083 §4.4 bis : protéger les élèves).
      # joined_via : Entities::Classroom::StudentArrivalChannel.
      # newcomer : arrivé depuis moins de NEW_FOR (ADR-0085 §4.4).
      # self_practice_count : sessions « fait seul » des SELF_PRACTICE_DAYS derniers jours (ADR-0089 §4.2), 0 sans aucune.
      # grade : la note sur 20 dans la classe (Entities::Classroom::RosterGrade), nil sans exercice assigné fait.
      StudentRow = Data.define(:public_id, :display_name, :contact, :last_score_percent, :last_session_public_id, :photo_version,
                               :joined_via, :newcomer, :self_practice_count, :grade)
      # counts : AssignmentFollowUpQuery::Counts, nil sans show_follow_up (FollowAssignmentPolicy, ADR-0072 §4.5).
      # comprehension : Assessment::ComprehensionSummaryQuery::Summary (ADR-0079), nil sans show_follow_up, comme counts.
      AssignmentRow = Data.define(:public_id, :exercise_title, :material_name, :material_category, :due_on, :counts,
                                  :comprehension)
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category,
                              :essentials_count)

      STUDENT_COLUMNS = %w[users.id users.public_id users.first_name users.last_name users.contact classroom_students.joined_via
                           classroom_students.joined_at].freeze
      # ADR-0085 §4.4 : un élève est « nouveau » pendant 7 jours après son arrivée ; calcul de lecture, sans colonne.
      NEW_FOR = 7.days
      RosterGrade = Entities::Classroom::RosterGrade
      NO_ROSTER = { students: nil, students_total: nil, grade_group: nil, grade_counts: nil }.freeze
      # ADR-0097 §4.7 : la liste des élèves se lit trente par trente, cumulativement, dans son groupe de note.
      PER_PAGE = 30
      # Une classe a au plus MAX_STUDENTS_LIMIT élèves : au-delà de cette page, la liste est déjà entière. Un ?page= géant ne
      # déborde donc jamais le LIMIT (bigint) de PostgreSQL.
      MAX_PAGE = (Entities::Classroom::Classroom::MAX_STUDENTS_LIMIT / PER_PAGE.to_f).ceil
      # ADR-0089 §4.2 : la fenêtre de « fait seul », aujourd'hui compris.
      SELF_PRACTICE_DAYS = 7
      # UDR-0081 §3.7 : les nouveaux d'abord, du plus récent au plus ancien ; les autres (NULL) gardent l'ordre par nom.
      NEWCOMERS_FIRST = "CASE WHEN classroom_students.joined_at > ? THEN classroom_students.joined_at END DESC NULLS LAST".freeze
      # « Awa Bamba » se trouve par « awa », « bamba » ou « awa bamba » (UDR-0054 §3.9).
      STUDENT_NAME = "concat_ws(' ', users.first_name, users.last_name)".freeze
      ASSIGNMENT_COLUMNS = %w[classroom_assignments.id classroom_assignments.public_id exercises.title materials.name
                              materials.category classroom_assignments.due_on].freeze
      COURSE_COLUMNS = %w[courses.id courses.slug courses.name courses.subtitle levels.name series.name materials.name
                          materials.category].freeze

      # search : « Chercher un élève » ; vide ou nil → toute la liste. Il ne filtre que les élèves de cette classe.
      # teacher_id : l'enseignant qui regarde (ses jours, sa matière) ; nil pour l'équipe, qui voit toutes les matières.
      # today : la date d'Abidjan (Time.zone) qui clôt la fenêtre de « fait seul » ; jamais Date.today (fuseau du serveur).
      # page : entier ≥ 1, la liste rend les page × PER_PAGE premiers élèves (ADR-0097 §4.7) ; toute autre valeur vaut 1.
      # note : le groupe demandé (« 0-10 », « 11-15 », « 16-20 », « none ») ; inconnu ou absent, le premier non vide.
      # → Overview | nil
      def call(public_id:, show_roster:, search: nil, teacher_id: nil, show_follow_up: false, today: Time.zone.today, page: 1,
               note: nil)
        id, level_id, series_id = Orm::Classroom.where(public_id:).pick(:id, :level_id, :series_id)
        return if id.nil?

        since = Time.current - NEW_FOR
        roster = show_roster ? roster(id, search, since, today, page, note) : NO_ROSTER
        Overview.new(**roster, new_students_count: (new_students_count(id, since) if show_roster),
                     session_days: (session_days(teacher_id, id) if teacher_id),
                     assignments: assignments(id, show_follow_up), courses: courses(level_id, series_id, teacher_id))
      end

      # ADR-0089 §4.2 : une session « fait seul » est terminée, standard (les remédiations restent hors du compte) et sans
      # assignation ; son jour est celui de started_at à Abidjan, dans les `days` derniers jours, today compris.
      # DirectionHomeQuery et la fiche d'un élève (StudentFileQuery, 30 jours) reprennent cette définition.
      # → relation d'Orm::ExerciseSession
      def self.self_practice(today, days: SELF_PRACTICE_DAYS)
        window = (today - (days - 1)).in_time_zone...(today + 1).in_time_zone
        Orm::ExerciseSession.where(status: "completed", kind: "standard", classroom_assignment_id: nil, started_at: window)
      end

      # ADR-0101 §4.4 : le cours est-il l'un de ceux que la page de la classe affiche pour cet acteur (niveau, série, et matière
      # de l'enseignant ; toute matière pour l'équipe) ? Une seule requête. → true | false
      def shown_course?(public_id:, course_slug:, teacher_id: nil)
        level_id, series_id = Orm::Classroom.where(public_id:).pick(:level_id, :series_id)
        return false if level_id.nil?

        course_scope(level_id, series_id, teacher_id).where(slug: course_slug).exists?
      end

      private

      # Décision du porteur du 2026-10-16 : sans recherche, les élèves d'un groupe de note ; avec, toute la classe. Les notes de
      # toute la classe en une requête, les groupes en une autre ; les lectures par élève (dernière session, photo, « fait
      # seul ») ne portent que sur les lignes rendues. → { students:, students_total:, grade_group:, grade_counts: }
      def roster(classroom_id, search, since, today, page, note)
        members = Orm::ClassroomStudent.joins(:student).where(classroom_id:, left_at: nil)
        grades = grades(classroom_id)
        groups = members.pluck(:student_id).group_by { RosterGrade.group_for(grades[it]) }
        grade_counts = RosterGrade::KEYS.to_h { [ it, groups.fetch(it, []).size ] }
        grade_group = RosterGrade.selected(note, grade_counts) if Queries::Shared::TextSearch.normalize(search).empty?
        scope = if grade_group
          members.where(student_id: groups.fetch(grade_group, []))
        else
          Queries::Shared::TextSearch.apply(members, search, columns: [ STUDENT_NAME ])
        end
        { students: students(scope, grades, since, today, page), grade_group:, grade_counts:,
          students_total: grade_group ? grade_counts.fetch(grade_group) : scope.count }
      end

      # { student_id => note sur 20 } : la moyenne des meilleurs scores de chaque élève aux exercices assignés actifs de la
      # classe, sessions faites rattachées à l'assignation, remédiation comprise (ADR-0079 §4.1), en une requête.
      def grades(classroom_id)
        bests = Orm::ExerciseSession.joins(:classroom_assignment)
                                    .where(status: "completed", classroom_assignments: { classroom_id:, status: "active" })
                                    .group(:student_id, :classroom_assignment_id)
                                    .select(:student_id, "MAX(exercise_sessions.score_percent) AS best")
        Orm::ExerciseSession.unscoped.from(bests, :bests).group("bests.student_id")
                            .pluck("bests.student_id", Arel.sql("AVG(bests.best)"))
                            .to_h { |id, mean| [ id, RosterGrade.grade_for(mean.to_f) ] }
      end

      def students(scope, grades, since, today, page)
        rows = scope.order(Arel.sql(Orm::ClassroomStudent.sanitize_sql_array([ NEWCOMERS_FIRST, since ])), "users.last_name", "users.first_name")
                    .limit(PER_PAGE * (page.is_a?(Integer) && page.positive? ? [ page, MAX_PAGE ].min : 1))
                    .pluck(*STUDENT_COLUMNS)
        sessions = last_sessions(rows.map(&:first))
        photos = Queries::Identity::PhotoVersions.for(user_ids: rows.map(&:first))
        practice = self.class.self_practice(today).where(student_id: rows.map(&:first)).group(:student_id).count

        rows.map do |id, public_id, first_name, last_name, contact, joined_via, joined_at|
          score, session_public_id = sessions[id]
          StudentRow.new(public_id:, display_name: "#{first_name} #{last_name}", contact: Entities::Identity::Contact.mask(contact),
                         last_score_percent: score, last_session_public_id: session_public_id, photo_version: photos[id],
                         joined_via:, newcomer: joined_at > since, self_practice_count: practice.fetch(id, 0), grade: grades[id])
        end
      end

      def new_students_count(classroom_id, since)
        Orm::ClassroomStudent.where(classroom_id:, left_at: nil).where("classroom_students.joined_at > ?", since).count
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
        rows = course_scope(level_id, series_id, teacher_id)
               .order("materials.name", "courses.name", "courses.id").pluck(*COURSE_COLUMNS)
        essentials = Orm::Essential.where(course_id: rows.map(&:first), status: "published").group(:course_id).count
        rows.map do |id, slug, name, subtitle, level_name, series_name, material_name, material_category|
          CourseRow.new(slug:, name:, subtitle:, level_name:, series_name:, material_name:, material_category:,
                        essentials_count: essentials.fetch(id, 0))
        end
      end

      def course_scope(level_id, series_id, teacher_id)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
                           .where(status: "published", level_id:, series_id: [ nil, series_id ].uniq)
        teacher_id ? scope.where(material_id: Orm::TeacherProfile.where(user_id: teacher_id).select(:material_id)) : scope
      end
    end
  end
end
