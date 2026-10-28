# 🧠 DOMAINE · Ports::Assessment::ExerciseSessionRepositoryPort
# Rôle : contrat des sessions d'exercice et de leurs tentatives immuables
# ADR  : 0033, 0043, 0054, 0091, 0112
module Ports
  module Assessment
    module ExerciseSessionRepositoryPort
      # lock: true = verrou (SELECT … FOR UPDATE), dans une transaction. → Entities::Assessment::ExerciseSession | nil
      def find_by_public_id(public_id:, lock: false)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Session ouverte de l'élève sur l'exercice. → ExerciseSession | nil
      def started_for(student_id:, exercise_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #started_for"
      end

      # Une session started existe déjà (index partiel) : la renvoie. → ExerciseSession
      def start(session:)
        raise NotImplementedError, "#{self.class} doit implémenter #start"
      end

      # → true
      def abandon(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #abandon"
      end

      # Insère la tentative et met à jour answered_count, correct_count, progress_percent. → :recorded | :duplicate
      # response_text : texte saisi (trous, nombre, ADR-0091), selected_answer_ids vide alors.
      def record_attempt(session_id:, question_id:, selected_answer_ids:, correct:, at:, response_text: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #record_attempt"
      end

      # Enregistre les tentatives d'une copie, une par question, avec les compteurs de la session (ADR copie à rendre §6).
      # attempts : [{ question_id:, selected_answer_ids:, response_text:, correct:, unanswered: }]
      # → :ok | :duplicate (une tentative existait déjà pour cette session)
      def record_copy(session_id:, attempts:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_copy"
      end

      # → [Entities::Assessment::QuestionAttempt]
      def attempts(session_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #attempts"
      end

      # UPDATE … WHERE status = 'started' : pose completed, score_percent et completed_at. → true
      def complete(id:, score_percent:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #complete"
      end
    end
  end
end
