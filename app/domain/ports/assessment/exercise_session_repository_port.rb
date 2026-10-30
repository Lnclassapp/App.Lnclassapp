# 🧠 DOMAINE · Ports::Assessment::ExerciseSessionRepositoryPort
# Rôle : contrat des sessions d'exercice et de leurs tentatives immuables
# ADR  : 0033, 0043, 0054, 0091, 0112, 0115, 0120-questions-a-plusieurs-cases-et-indice
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

      # Une session started existe déjà (index partiel) : la renvoie. → ExerciseSession, jamais nil (violation d'unicité sans
      # session ouverte à renvoyer : l'erreur remonte).
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
      # attempts : [{ question_id:, selected_answer_ids:, response_text:, correct:, unanswered:, blank_responses:, blank_results: }]
      # blank_responses ([String]) et blank_results ([Boolean]) : la réponse et le verdict de chaque case, dans l'ordre des cases ;
      # vides pour une question à une seule case (ADR-0120 questions à plusieurs cases §4).
      # → :ok | :duplicate (une tentative existait déjà pour cette session)
      def record_copy(session_id:, attempts:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_copy"
      end

      # Enregistre l'ouverture de l'indice d'une question dans la copie en cours : ajoute question_id à hinted_question_ids seulement
      # s'il n'y est pas, sous le verrou de la session (dix ouvertures donnent une seule mention). → :recorded | :already_opened
      def record_hint(session_id:, question_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #record_hint"
      end

      # → [Entities::Assessment::QuestionAttempt]
      def attempts(session_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #attempts"
      end

      # Les fins (Time) des 3 dernières copies terminées de l'élève sur l'exercice, toutes sortes confondues, de la plus récente
      # à la plus ancienne ; les copies abandonnées ou en cours n'y sont pas (ADR-0115, RestartPause). → [Time]
      def recent_completions(student_id:, exercise_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #recent_completions"
      end

      # Comme recent_completions, pour plusieurs exercices en une requête (l'accueil) : les `limit` dernières fins par exercice.
      # → { exercise_id => [Time] } (un exercice sans copie terminée n'a pas de clé)
      def recent_completions_by_exercise(student_id:, exercise_ids:, limit: Entities::Assessment::RestartPause::STREAK)
        raise NotImplementedError, "#{self.class} doit implémenter #recent_completions_by_exercise"
      end

      # UPDATE … WHERE status = 'started' : pose completed, score_percent et completed_at. → true
      def complete(id:, score_percent:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #complete"
      end
    end
  end
end
