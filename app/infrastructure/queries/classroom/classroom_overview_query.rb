# 🔌 INFRA · Queries::Classroom::ClassroomOverviewQuery
# Rôle : corps de la page d'une classe (CL-10) : jours de séance de l'enseignant, exercices assignés et leurs comptes, cours de ses matières, élèves filtrés par badge de classe puis par trente, au numéro masqué (nouveaux, voie)
# ADR  : 0026, 0028, 0048, 0060, 0062, 0072, 0079, 0083 (§4.4 bis), 0085, 0089 (§4.2), 0097 (§4.7), 0103 · UDR : enseignant §3.2 et §3.5, 0027, 0047, 0054, 0062 (§3.4), 0072 (§3.4), 0079 (§3.8 ter), 0081 (§3.7), 0084 (§3.7), 0108, 0127 (§3.1)
module Queries
  module Classroom
    class ClassroomOverviewQuery
      # students : nil sans show_roster (ReadClassroomPolicy) — la liste nominative n'est alors même pas lue.
      # badge_filter : le filtre `badge=` demandé (une clé de BADGE_FILTERS), nil pour « Tous » ou un filtre inconnu.
      # students_total : les élèves du filtre qui répondent à la recherche, dont students ne rend que les
      # page × PER_PAGE premiers (ADR-0097 §4.7). Les deux : nil sans show_roster.
      # new_students_count : les nouveaux de toute la classe, quelle que soit la recherche ; nil sans show_roster.
      # session_days : jours (1 = lundi … 6 = samedi) de l'enseignant pour la classe, [] s'il ne les a pas renseignés ;
      # nil sans teacher_id (l'équipe n'a pas de jours, ADR-0072 §4.2).
      # school_sigle : « CSMT », sous le titre de la page (UDR enseignant §3.5) ; nil si l'établissement n'en a pas.
      Overview = Data.define(:students, :students_total, :badge_filter, :new_students_count, :session_days,
                             :assignments, :courses, :school_sigle)
      # last_session_public_id : la dernière session terminée, dont l'enseignant ouvre le résultat ; nil sans session.
      # photo_version : nil sans photo (ADR-0060).
      # contact : toujours masqué (« 07 •• •• •• 04 »), pour tout lecteur ; le numéro complet ne quitte pas cette requête
      # (ADR-0083 §4.4 bis : protéger les élèves).
      # joined_via : Entities::Classroom::StudentArrivalChannel.
      # newcomer : arrivé depuis moins de NEW_FOR (ADR-0085 §4.4).
      # self_practice_count : sessions « fait seul » des SELF_PRACTICE_DAYS derniers jours (ADR-0089 §4.2), 0 sans aucune.
      # grade : la note sur 20 dans la classe (Entities::Classroom::RosterGrade), nil sans exercice assigné fait.
      # badge : le badge de classe (Grading.class_badge_for : :bronze, :silver, :gold, :diamond), nil pour « Pas encore » ;
      # done_count, late_count, assigned_count : « 9 faits sur 18 · 1 en retard » ; en retard = pas fait et échu (due_on avant today),
      # comme « 7 en retard » du rapport et de l'accueil (PRD CA-G6, CA-I4) ; exercices assignés actifs de la classe.
      StudentRow = Data.define(:public_id, :display_name, :contact, :last_score_percent, :last_session_public_id, :photo_version,
                               :joined_via, :newcomer, :self_practice_count, :grade, :badge, :done_count, :late_count,
                               :assigned_count)
      # La place d'un élève dans la classe, lue une fois pour toute la liste.
      Standing = Data.define(:grade, :badge, :done, :late)
      Totals = Data.define(:assigned, :overdue)
      # counts : AssignmentFollowUpQuery::Counts, nil sans show_follow_up (FollowAssignmentPolicy, ADR-0072 §4.5).
      # comprehension : Assessment::ComprehensionSummaryQuery::Summary (ADR-0079), nil sans show_follow_up, comme counts.
      AssignmentRow = Data.define(:public_id, :exercise_title, :material_name, :material_category, :due_on, :counts,
                                  :comprehension, :exercise_type, :material_slug)
      # material_slug : une bande par matière pour l'enseignant de plusieurs matières (UDR-0127 §3.1).
      CourseRow = Data.define(:slug, :name, :subtitle, :level_name, :series_name, :material_name, :material_category,
                              :essentials_count, :material_slug)

      STUDENT_COLUMNS = %w[users.id users.public_id users.first_name users.last_name users.contact classroom_students.joined_via
                           classroom_students.joined_at].freeze
      # ADR-0085 §4.4 : un élève est « nouveau » pendant 7 jours après son arrivée ; calcul de lecture, sans colonne.
      NEW_FOR = 7.days
      RosterGrade = Entities::Classroom::RosterGrade
      Grading = Entities::Assessment::Grading
      # Le paramètre `badge=` de la liste (UDR enseignant §3.5) ; « none » : les élèves « Pas encore ».
      NO_BADGE = "none"
      BADGE_FILTERS = [ *Grading::BADGE_ORDER.map(&:to_s), NO_BADGE ].freeze
      NO_ROSTER = { students: nil, students_total: nil, badge_filter: nil }.freeze
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
                              materials.category classroom_assignments.due_on exercises.exercise_type materials.slug].freeze
      COURSE_COLUMNS = %w[courses.id courses.slug courses.name courses.subtitle levels.name series.name materials.name
                          materials.category materials.slug materials.id].freeze

      # search : « Chercher un élève » ; vide ou nil → toute la liste. Il ne filtre que les élèves de cette classe.
      # teacher_id : l'enseignant qui regarde (ses jours, ses matières dans l'établissement de la classe, ADR-0103) ; nil
      # pour l'équipe, qui voit toutes les matières.
      # today : la date d'Abidjan (Time.zone) qui clôt la fenêtre de « fait seul » ; jamais Date.today (fuseau du serveur).
      # page : entier ≥ 1, la liste rend les page × PER_PAGE premiers élèves (ADR-0097 §4.7) ; toute autre valeur vaut 1.
      # badge : le filtre demandé (« bronze », « silver », « gold », « diamond », « none ») ; inconnu ou absent, toute la classe.
      # → Overview | nil
      def call(public_id:, show_roster:, search: nil, teacher_id: nil, show_follow_up: false, today: Time.zone.today, page: 1,
               badge: nil)
        id, level_id, series_id, school_id, school_sigle =
          Orm::Classroom.joins(:school).where(classrooms: { public_id: }).pick("classrooms.id", "classrooms.level_id",
                                                                              "classrooms.series_id", "classrooms.school_id",
                                                                              "schools.sigle")
        return if id.nil?

        since = Time.current - NEW_FOR
        roster = show_roster ? roster(id, search, since, today, page, badge) : NO_ROSTER
        Overview.new(**roster, new_students_count: (new_students_count(id, since) if show_roster),
                     session_days: (session_days(teacher_id, id) if teacher_id),
                     assignments: assignments(id, show_follow_up),
                     courses: courses(level_id, series_id, teacher_material_ids(teacher_id, school_id)), school_sigle:)
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
        level_id, series_id, school_id = Orm::Classroom.where(public_id:).pick(:level_id, :series_id, :school_id)
        return false if level_id.nil?

        course_scope(level_id, series_id, teacher_material_ids(teacher_id, school_id)).where(slug: course_slug).exists?
      end

      private

      # UDR enseignant §3.5 : le filtre de badge et la recherche se combinent. Le rang de chaque élève (note, badge, faits) se lit
      # pour toute la classe en deux requêtes ; les lectures par élève (dernière session, photo, « fait seul ») ne portent que
      # sur les lignes rendues. → { students:, students_total:, badge_filter: }
      def roster(classroom_id, search, since, today, page, badge)
        members = Orm::ClassroomStudent.joins(:student).where(classroom_id:, left_at: nil)
        standings, totals = standings(classroom_id, today)
        badge_filter = badge if BADGE_FILTERS.include?(badge)
        scope = Queries::Shared::TextSearch.apply(members, search, columns: [ STUDENT_NAME ])
        scope = badge_scope(scope, standings, badge_filter) if badge_filter
        { students: students(scope, standings, totals, since, today, page), badge_filter:, students_total: scope.count }
      end

      # Un élève sans exercice fait n'a pas de rang : il est « Pas encore », comme celui sous la moyenne de Bronze.
      def badge_scope(scope, standings, badge_filter)
        return scope.where.not(student_id: standings.select { |_, standing| standing.badge }.keys) if badge_filter == NO_BADGE

        scope.where(student_id: standings.select { |_, standing| standing.badge == badge_filter.to_sym }.keys)
      end

      # [{ student_id => Standing }, Totals] : la moyenne des meilleurs scores de chaque élève présent aux exercices assignés
      # actifs de la classe (remédiation comprise, ADR-0079 §4.1), le badge de classe qu'elle donne (Grading.class_badge_for),
      # ses exercices faits et ceux échus qu'il n'a pas faits. Un élève sans exercice fait n'a pas de Standing (Totals.overdue
      # lui tient lieu de retard). Deux requêtes, quel que soit l'effectif.
      def standings(classroom_id, today)
        due_dates = Orm::ClassroomAssignment.where(classroom_id:, status: "active").pluck(:id, :due_on).to_h
        overdue = due_dates.select { |_, due_on| due_on && due_on < today }.keys
        scores = Queries::Assessment::AssignmentScores.for(classroom_id:, assignment_ids: due_dates.keys)
        bests = Hash.new { |hash, key| hash[key] = {} }
        scores.each { |assignment_id, rows| rows.each { bests[it.student_id][assignment_id] = it.scores.max } }
        [ bests.transform_values { standing(it, overdue) }, Totals.new(assigned: due_dates.size, overdue: overdue.size) ]
      end

      def standing(bests, overdue)
        scores = bests.values
        Standing.new(grade: RosterGrade.grade_for(scores.sum.fdiv(scores.size)), done: scores.size, late: (overdue - bests.keys).size,
                     badge: Grading.class_badge_for(scores:, all_perfect: scores.all? { Grading.perfect?(it) }))
      end

      # Ses matières dans l'établissement de la classe, dans l'ordre d'ajout (ADR-0103 §4.5) ; nil pour l'équipe.
      def teacher_material_ids(teacher_id, school_id)
        Orm::TeacherSchoolMaterial.where(teacher_id:, school_id:).in_order.pluck(:material_id) if teacher_id
      end

      def students(scope, standings, totals, since, today, page)
        rows = scope.order(Arel.sql(Orm::ClassroomStudent.sanitize_sql_array([ NEWCOMERS_FIRST, since ])), "users.last_name", "users.first_name")
                    .limit(PER_PAGE * (page.is_a?(Integer) && page.positive? ? [ page, MAX_PAGE ].min : 1))
                    .pluck(*STUDENT_COLUMNS)
        sessions = last_sessions(rows.map(&:first))
        photos = Queries::Identity::PhotoVersions.for(user_ids: rows.map(&:first))
        practice = self.class.self_practice(today).where(student_id: rows.map(&:first)).group(:student_id).count

        rows.map do |id, public_id, first_name, last_name, contact, joined_via, joined_at|
          score, session_public_id = sessions[id]
          standing = standings[id]
          StudentRow.new(public_id:, display_name: "#{first_name} #{last_name}", contact: Entities::Identity::Contact.mask(contact),
                         last_score_percent: score, last_session_public_id: session_public_id, photo_version: photos[id],
                         joined_via:, newcomer: joined_at > since, self_practice_count: practice.fetch(id, 0), grade: standing&.grade,
                         badge: standing&.badge, done_count: standing&.done.to_i, late_count: standing ? standing.late : totals.overdue,
                         assigned_count: totals.assigned)
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
        rows.map do |id, public_id, exercise_title, material_name, material_category, due_on, exercise_type, material_slug|
          AssignmentRow.new(public_id:, exercise_title:, material_name:, material_category:, due_on:, counts: counts[id],
                            comprehension: comprehension[id], exercise_type:, material_slug:)
        end
      end

      # Comptes et résumé de compréhension de toutes les assignations, en un nombre de requêtes constant (ADR-0079).
      def follow_up(classroom_id, assignment_ids)
        [ AssignmentFollowUpQuery.counts(classroom_id:, assignment_ids:),
          Queries::Assessment::ComprehensionSummaryQuery.for(classroom_id:, assignment_ids:) ]
      end

      # Bloc « Cours » (UDR-0062 §3.4, memo Q18) : le chemin de l'enseignant vers les exercices. La règle d'AudienceFilter
      # (niveau de la classe, série vide ou la sienne), réduite aux matières de l'enseignant dans l'établissement de la classe
      # (material_ids, ADR-0103 §4.5), rangées dans son ordre ; nil : toutes, par nom (l'équipe).
      def courses(level_id, series_id, material_ids)
        rows = course_scope(level_id, series_id, material_ids).order("materials.name", "courses.name", "courses.id").pluck(*COURSE_COLUMNS)
        rows = rows.sort_by.with_index { |row, index| [ material_ids.index(row.last), index ] } if material_ids
        essentials = Orm::Essential.where(course_id: rows.map(&:first), status: "published").group(:course_id).count
        rows.map do |id, slug, name, subtitle, level_name, series_name, material_name, material_category, material_slug|
          CourseRow.new(slug:, name:, subtitle:, level_name:, series_name:, material_name:, material_category:,
                        essentials_count: essentials.fetch(id, 0), material_slug:)
        end
      end

      def course_scope(level_id, series_id, material_ids)
        scope = Orm::Course.joins(:level, :material).left_joins(:series)
                           .where(status: "published", level_id:, series_id: [ nil, series_id ].uniq)
        material_ids ? scope.where(material_id: material_ids) : scope
      end
    end
  end
end
