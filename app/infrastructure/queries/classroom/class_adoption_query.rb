# 🔌 INFRA · Queries::Classroom::ClassAdoptionQuery
# Rôle : entonnoir enseignant E1 à E6, indice classes vides, élèves avec ou sans enseignant et écoles du CRM, en lecture seule (comptes uniquement)
# ADR  : XXXX (adoption par les classes lue sur les tables), 0024, 0041
module Queries
  module Classroom
    class ClassAdoptionQuery
      CHANNELS = %w[standard colleague direction team code].freeze
      STUDENT_CHANNELS = %w[standard link code].freeze
      STAGES = %w[prospect demo_done subscribed lost].freeze
      ADOPTED_MIN_STUDENTS = 5
      INTERACTION_DAYS = 30

      Steps = Data.define(:e1, :blocked, :e2, :e3, :e4, :e5, :e6) do
        def self.zero = new(*Array.new(members.size, 0))
        def +(other) = with(**to_h.to_h { |name, count| [ name, count + other.public_send(name) ] })
      end
      CrmRow = Data.define(:stage, :schools, :with_interaction, :with_teacher, :with_open_class, :with_populated_class)
      Row = Data.define(:total, :by_channel, :by_month, :empty_with_assignment, :empty_without_assignment, :students, :median_students,
                        :crm_stages, :crm_interactions_30d) do
        # Les compteurs que lit Entities::Classroom::AdoptionVerdict.
        def verdict_counters
          total.to_h.merge(empty_with_assignment:, empty_without_assignment:, median_students_per_populated_class: median_students,
                           crm_schools_with_interaction: crm_stages.sum(&:with_interaction))
        end
      end

      # Les CTE se lisent de haut en bas : enseignants (E1), classes ouvertes de l'année, élèves en cours, effectif par classe, classes cochées.
      # Une ligne par enseignant avec ses étages en 0/1, regroupée par voie et par mois d'inscription.
      TEACHERS = <<~SQL.squish.freeze
        WITH teachers AS (
          SELECT u.id, u.created_at, tp.joined_via, ts.school_id
            FROM users u
            JOIN teacher_profiles tp ON tp.user_id = u.id
            JOIN teacher_schools ts ON ts.teacher_id = u.id AND ts."primary"
           WHERE u.role = 'teacher' AND u.anonymized_at IS NULL),
        open_classes AS (SELECT id, school_id FROM classrooms WHERE status = 'active' AND school_year = :year),
        class_stats AS (
          SELECT oc.id AS classroom_id,
                 COUNT(cs.student_id) AS students,
                 COUNT(cs.student_id) FILTER (WHERE EXISTS (SELECT 1 FROM exercise_sessions es WHERE es.student_id = cs.student_id)) AS working
            FROM open_classes oc
            LEFT JOIN classroom_students cs ON cs.classroom_id = oc.id AND cs."primary" AND cs.left_at IS NULL
                 AND EXISTS (SELECT 1 FROM users s WHERE s.id = cs.student_id AND s.anonymized_at IS NULL)
           GROUP BY oc.id),
        ticked AS (
          SELECT tc.teacher_id, tc.classroom_id, st.students, st.working
            FROM teacher_classrooms tc JOIN class_stats st ON st.classroom_id = tc.classroom_id),
        flags AS (
          SELECT t.joined_via, to_char(t.created_at, 'YYYY-MM') AS month,
                 EXISTS (SELECT 1 FROM open_classes oc WHERE oc.school_id = t.school_id) AS e2,
                 EXISTS (SELECT 1 FROM ticked k WHERE k.teacher_id = t.id) AS e3,
                 EXISTS (SELECT 1 FROM ticked k WHERE k.teacher_id = t.id AND k.students >= 1) AS e4,
                 EXISTS (SELECT 1 FROM classroom_assignments a WHERE a.assigned_by_id = t.id) AS e5,
                 EXISTS (SELECT 1 FROM ticked k WHERE k.teacher_id = t.id AND k.working >= :adopted) AS e6,
                 EXISTS (SELECT 1 FROM ticked k JOIN classroom_assignments a ON a.classroom_id = k.classroom_id AND a.assigned_by_id = t.id
                          WHERE k.teacher_id = t.id) AS gave
            FROM teachers t)
        SELECT joined_via, month,
               COUNT(*) AS e1,
               COUNT(*) FILTER (WHERE NOT e2) AS blocked,
               COUNT(*) FILTER (WHERE e2) AS e2,
               COUNT(*) FILTER (WHERE e3) AS e3,
               COUNT(*) FILTER (WHERE e4) AS e4,
               COUNT(*) FILTER (WHERE e5) AS e5,
               COUNT(*) FILTER (WHERE e6) AS e6,
               COUNT(*) FILTER (WHERE e3 AND NOT e4 AND gave) AS empty_with_assignment,
               COUNT(*) FILTER (WHERE e3 AND NOT e4 AND NOT gave) AS empty_without_assignment
          FROM flags GROUP BY joined_via, month ORDER BY month, joined_via
      SQL

      # Élèves en cours des classes ouvertes, selon que la classe est cochée par un enseignant (non anonymisé) ou non, puis la médiane
      # d'élèves par classe cochée et peuplée.
      STUDENTS = <<~SQL.squish.freeze
        WITH open_classes AS (SELECT id FROM classrooms WHERE status = 'active' AND school_year = :year),
        roster AS (
          SELECT cs.classroom_id, cs.joined_via
            FROM classroom_students cs JOIN open_classes oc ON oc.id = cs.classroom_id JOIN users s ON s.id = cs.student_id
           WHERE cs."primary" AND cs.left_at IS NULL AND s.anonymized_at IS NULL),
        with_teacher AS (
          SELECT DISTINCT tc.classroom_id FROM teacher_classrooms tc JOIN users t ON t.id = tc.teacher_id WHERE t.anonymized_at IS NULL)
        SELECT 'students' AS part, (r.classroom_id IN (SELECT classroom_id FROM with_teacher))::text AS ticked, r.joined_via AS channel,
               COUNT(*)::float AS value
          FROM roster r GROUP BY ticked, channel
        UNION ALL
        SELECT 'median', NULL, NULL, percentile_cont(0.5) WITHIN GROUP (ORDER BY n)
          FROM (SELECT classroom_id, COUNT(*) AS n FROM roster WHERE classroom_id IN (SELECT classroom_id FROM with_teacher) GROUP BY classroom_id) populated
      SQL

      # Écoles actives par étape saisie (prospect sans ligne CRM), croisées avec l'usage réel.
      SCHOOLS = <<~SQL.squish.freeze
        SELECT COALESCE(a.stage, 'prospect') AS stage,
               COUNT(*) AS schools,
               COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM crm_interactions i WHERE i.school_id = s.id)) AS with_interaction,
               COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM teacher_schools ts JOIN users u ON u.id = ts.teacher_id
                                              WHERE ts.school_id = s.id AND ts."primary" AND u.anonymized_at IS NULL)) AS with_teacher,
               COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM classrooms c WHERE c.school_id = s.id AND c.status = 'active' AND c.school_year = :year)) AS with_open_class,
               COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM classrooms c JOIN classroom_students cs ON cs.classroom_id = c.id
                                                JOIN users st ON st.id = cs.student_id
                                              WHERE c.school_id = s.id AND c.status = 'active' AND c.school_year = :year
                                                AND cs."primary" AND cs.left_at IS NULL AND st.anonymized_at IS NULL)) AS with_populated_class
          FROM schools s LEFT JOIN crm_accounts a ON a.school_id = s.id
         WHERE s.status = 'active' GROUP BY 1
      SQL
      INTERACTIONS = "SELECT COUNT(*) FROM crm_interactions WHERE occurred_at >= :since".freeze

      def call(today:)
        year = Entities::Classroom::SchoolYear.current(today)
        teachers = rows(TEACHERS, year:, adopted: ADOPTED_MIN_STUDENTS)
        students = rows(STUDENTS, year:)
        build(teachers:, students:, schools: rows(SCHOOLS, year:), since: (today - INTERACTION_DAYS).beginning_of_day)
      end

      private

      def rows(sql, **binds) = connection.select_all(Orm::User.sanitize_sql_array([ sql, binds ])).to_a

      def connection = Orm::User.connection

      def build(teachers:, students:, schools:, since:)
        steps = ->(group) { group.sum(Steps.zero) { |row| Steps.new(*Steps.members.map { |name| row.fetch(name.to_s) }) } }
        Row.new(total: steps.call(teachers), by_channel: by_channel(teachers, steps), by_month: teachers.group_by { it["month"] }.transform_values(&steps),
                empty_with_assignment: teachers.sum { it["empty_with_assignment"] }, empty_without_assignment: teachers.sum { it["empty_without_assignment"] },
                students: split_students(students), median_students: students.find { it["part"] == "median" }.fetch("value"),
                crm_stages: crm_stages(schools), crm_interactions_30d: connection.select_value(Orm::User.sanitize_sql_array([ INTERACTIONS, { since: } ])).to_i)
      end

      def by_channel(teachers, steps)
        grouped = teachers.group_by { it["joined_via"] }
        CHANNELS.index_with { steps.call(grouped.fetch(it, [])) }
      end

      def split_students(rows)
        counts = rows.select { it["part"] == "students" }
        { "with_teacher" => channel_counts(counts, "true"), "without_teacher" => channel_counts(counts, "false") }
      end

      def channel_counts(rows, ticked)
        rows.select { it["ticked"] == ticked }.to_h { [ it["channel"], it["value"].to_i ] }
      end

      def crm_stages(schools)
        by_stage = schools.index_by { it["stage"] }
        STAGES.map do |stage|
          row = by_stage.fetch(stage, {})
          CrmRow.new(stage, *CrmRow.members.drop(1).map { |name| row.fetch(name.to_s, 0) })
        end
      end
    end
  end
end
