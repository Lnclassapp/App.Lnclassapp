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

      # ADR-0097 §4.5 : une médaille ne se lit dans une classe que si la session qui l'a enregistrée
      # (exercise_badges.exercise_session_id) appartient à une de ses assignations ; une médaille gagnée ailleurs n'existe pas ici.
      # → { assignment_id => { student_id => :bronze … } }
      def self.by_assignment(assignment_ids:, student_ids: nil)
        return {} if assignment_ids.empty?

        scope = Orm::ExerciseBadge.joins("JOIN exercise_sessions ON exercise_sessions.id = exercise_badges.exercise_session_id")
                                  .where(exercise_sessions: { classroom_assignment_id: assignment_ids })
        scope = scope.where(student_id: student_ids) if student_ids
        scope.pluck("exercise_sessions.classroom_assignment_id", "exercise_badges.student_id", "exercise_badges.level")
             .each_with_object({}) { |(id, student_id, level), by_id| (by_id[id] ||= {})[student_id] = level.to_sym }
      end

      # UDR médailles : la répartition d'un devoir (« 8 Bronze · 6 Argent · 3 Or »), jamais une moyenne. Même lecture par classe
      # (ADR-0097 §4.5), pour les seuls élèves présents (adhésion non quittée, compte non anonymisé, comme le suivi).
      # → { assignment_id => { bronze: 8, silver: 6 … } } ; les paliers à zéro et les devoirs sans médaille sont absents.
      def self.distribution_by_assignment(assignment_ids:)
        return {} if assignment_ids.empty?

        Orm::ExerciseBadge.joins("JOIN exercise_sessions ON exercise_sessions.id = exercise_badges.exercise_session_id")
                          .joins("JOIN classroom_assignments ON classroom_assignments.id = exercise_sessions.classroom_assignment_id")
                          .joins("JOIN classroom_students ON classroom_students.classroom_id = classroom_assignments.classroom_id " \
                                 "AND classroom_students.student_id = exercise_badges.student_id AND classroom_students.left_at IS NULL")
                          .joins("JOIN users ON users.id = exercise_badges.student_id AND users.anonymized_at IS NULL")
                          .where(exercise_sessions: { classroom_assignment_id: assignment_ids })
                          .group("exercise_sessions.classroom_assignment_id", "exercise_badges.level").count
                          .each_with_object({}) { |((id, level), count), by_id| (by_id[id] ||= {})[level.to_sym] = count }
      end
    end
  end
end
