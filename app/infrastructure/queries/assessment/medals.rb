# 🔌 INFRA · Queries::Assessment::Medals
# Rôle : lectures partagées des médailles : celles d'une classe (gagnées par une session de ses assignations) et la copie traitée d'une session
# ADR  : 0097 (§4.5 : rien d'une autre classe), médailles lues à la clôture · une requête par appel, quel que soit le nombre d'élèves
module Queries
  module Assessment
    module Medals
      # Une session est traitée (elle donne une médaille, Grading.session_medal) si au moins une tentative a une réponse, ou si
      # son exercice a une question du cahier : le cahier n'a aucun champ, il compte comme traité (journal du chantier, À trancher).
      # Une question « remettre dans l'ordre » laissée telle quelle envoie un ordre : elle compte comme une réponse (UDR-0138).
      TREATED_SQL = "(EXISTS (SELECT 1 FROM question_attempts WHERE question_attempts.exercise_session_id = exercise_sessions.id " \
                    "AND question_attempts.unanswered = FALSE) OR EXISTS (SELECT 1 FROM questions " \
                    "WHERE questions.exercise_id = exercise_sessions.exercise_id AND questions.question_type = 'notebook'))".freeze

      LEVEL_RANK = Entities::Assessment::Grading::BADGE_ORDER.each_with_index.to_h.freeze
      PRESENT_SQL = "JOIN classroom_students ON classroom_students.classroom_id = classroom_assignments.classroom_id " \
                    "AND classroom_students.student_id = exercise_sessions.student_id AND classroom_students.left_at IS NULL " \
                    "JOIN users ON users.id = classroom_students.student_id AND users.anonymized_at IS NULL".freeze
      ASSIGNMENT_SQL = "JOIN classroom_assignments ON classroom_assignments.id = exercise_sessions.classroom_assignment_id".freeze

      # La médaille d'un élève dans une classe est celle de sa meilleure copie traitée d'une assignation de la classe
      # (Grading.session_medal), ou à défaut la médaille enregistrée dont la session en est une (ADR-0097 §4.5). Une médaille montée
      # ailleurs (fait seul, autre classe) réécrit exercise_badges.exercise_session_id : seules les sessions la gardent ici.
      # → { assignment_id => { student_id => :bronze … } }
      def self.by_assignment(assignment_ids:, student_ids: nil)
        return {} if assignment_ids.empty?

        sessions = Orm::ExerciseSession.where(classroom_assignment_id: assignment_ids)
        sessions = sessions.where(student_id: student_ids) if student_ids
        levels = best_levels(sessions, "exercise_sessions.classroom_assignment_id", "exercise_sessions.student_id")
        scope = Orm::ExerciseBadge.joins("JOIN exercise_sessions ON exercise_sessions.id = exercise_badges.exercise_session_id")
                                  .where(exercise_sessions: { classroom_assignment_id: assignment_ids })
        scope = scope.where(student_id: student_ids) if student_ids
        scope.pluck("exercise_sessions.classroom_assignment_id", "exercise_badges.student_id", "exercise_badges.level")
             .each { |id, student_id, level| raise_level(levels, [ id, student_id ], level.to_sym) }
        levels.each_with_object({}) { |((id, student_id), level), by_id| (by_id[id] ||= {})[student_id] = level }
      end

      # UDR médailles : la répartition d'un devoir (« 8 Bronze · 6 Argent · 3 Or »), jamais une moyenne. Même lecture par classe,
      # pour les seuls élèves présents (adhésion non quittée, compte non anonymisé, comme le suivi).
      # → { assignment_id => { bronze: 8, silver: 6 … } } ; les paliers à zéro et les devoirs sans médaille sont absents.
      def self.distribution_by_assignment(assignment_ids:)
        by_student = by_assignment(assignment_ids:)
        return {} if by_student.empty?

        present = present_pairs(assignment_ids, by_student.values.flat_map(&:keys).uniq)
        by_student.each_with_object({}) do |(id, levels), by_id|
          levels.each do |student_id, level|
            next unless present.include?([ id, student_id ])

            by_level = (by_id[id] ||= {})
            by_level[level] = by_level.fetch(level, 0) + 1
          end
        end
      end

      # Lecture de la direction (UDR médailles §2.4) : des médailles gagnées dans une assignation de la classe, une par exercice,
      # jamais une moyenne ni un classement. Les élèves présents seuls (ADR-0065 §4). Peu de requêtes, quel que soit le nombre de classes.
      # → { classroom_id => { student_id => { :bronze => 2 … } } }
      def self.by_classroom(classroom_ids:)
        return {} if classroom_ids.empty?

        sessions = Orm::ExerciseSession.joins(ASSIGNMENT_SQL).joins(PRESENT_SQL).where(classroom_assignments: { classroom_id: classroom_ids })
        levels = best_levels(sessions, "classroom_assignments.classroom_id", "exercise_sessions.student_id", "exercise_sessions.exercise_id")
        badges = Orm::ExerciseBadge.joins("JOIN exercise_sessions ON exercise_sessions.id = exercise_badges.exercise_session_id")
                                   .joins(ASSIGNMENT_SQL).joins(PRESENT_SQL.gsub("exercise_sessions.student_id", "exercise_badges.student_id"))
                                   .where(classroom_assignments: { classroom_id: classroom_ids })
                                   .pluck("classroom_assignments.classroom_id", "exercise_badges.student_id", "exercise_badges.exercise_id", "exercise_badges.level")
        badges.each { |classroom_id, student_id, exercise_id, level| raise_level(levels, [ classroom_id, student_id, exercise_id ], level.to_sym) }
        tally(levels) { |(classroom_id, student_id, _exercise_id), level| [ classroom_id, student_id, level ] }
      end

      # Les médailles gagnées dans les classes d'un établissement (anciens élèves : plus présents nulle part, d'où aucun filtre de
      # présence). → { student_id => { :bronze => 2 … } }
      def self.by_student_in_school(school_id:, student_ids:)
        return {} if student_ids.empty?

        sessions = Orm::ExerciseSession.joins(ASSIGNMENT_SQL).joins("JOIN classrooms ON classrooms.id = classroom_assignments.classroom_id")
                                       .where(classrooms: { school_id: }, exercise_sessions: { student_id: student_ids })
        levels = best_levels(sessions, "exercise_sessions.student_id", "exercise_sessions.exercise_id")
        badges = Orm::ExerciseBadge.joins("JOIN exercise_sessions ON exercise_sessions.id = exercise_badges.exercise_session_id")
                                   .joins(ASSIGNMENT_SQL).joins("JOIN classrooms ON classrooms.id = classroom_assignments.classroom_id")
                                   .where(classrooms: { school_id: }, exercise_badges: { student_id: student_ids })
                                   .pluck("exercise_badges.student_id", "exercise_badges.exercise_id", "exercise_badges.level")
        badges.each { |student_id, exercise_id, level| raise_level(levels, [ student_id, exercise_id ], level.to_sym) }
        levels.group_by { |(student_id, _exercise_id), _level| student_id }.transform_values { |rows| rows.map(&:last).tally }
      end

      # Le palier de la meilleure copie traitée de chaque groupe (le palier monte avec la note : la meilleure note donne la meilleure
      # médaille). Les copies vides n'en donnent aucune. → { clé de groupe => :bronze … }
      def self.best_levels(sessions, *group)
        sessions.where(status: "completed").where(TREATED_SQL).group(*group).maximum("exercise_sessions.score_percent")
                .transform_values { |score| Entities::Assessment::Grading.badge_for(score.to_i) }
      end

      def self.raise_level(levels, key, level)
        levels[key] = level if levels[key].nil? || LEVEL_RANK[level] > LEVEL_RANK[levels[key]]
      end

      def self.present_pairs(assignment_ids, student_ids)
        Orm::ClassroomAssignment.where(id: assignment_ids)
                                .joins("JOIN classroom_students ON classroom_students.classroom_id = classroom_assignments.classroom_id " \
                                       "AND classroom_students.left_at IS NULL AND classroom_students.student_id IN (#{student_ids.map(&:to_i).join(',')}) " \
                                       "JOIN users ON users.id = classroom_students.student_id AND users.anonymized_at IS NULL")
                                .pluck("classroom_assignments.id", "classroom_students.student_id").to_set
      end

      def self.tally(levels)
        levels.each_with_object({}) do |(key, level), by_id|
          classroom_id, student_id, level = yield(key, level)
          ((by_id[classroom_id] ||= {})[student_id] ||= Hash.new(0))[level] += 1
        end.transform_values { |students| students.transform_values(&:to_h) }
      end
      private_class_method :best_levels, :raise_level, :present_pairs, :tally
    end
  end
end
