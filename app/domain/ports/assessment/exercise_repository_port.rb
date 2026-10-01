# 🧠 DOMAINE · Ports::Assessment::ExerciseRepositoryPort
# Rôle : contrat de persistance des exercices, de leurs questions et de leurs propositions
# ADR  : 0035, 0036, 0039, 0054
module Ports
  module Assessment
    module ExerciseRepositoryPort
      # Avec questions, propositions et parents_published. → Entities::Assessment::Exercise | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Même hydratation, par id (la session ne connaît que exercise_id). → Entities::Assessment::Exercise | nil
      def find(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # Exercice, questions et propositions. → Entities::Assessment::Exercise
      def create(exercise:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # replace_questions : remplace questions et propositions (interdit dès qu'une session existe). → Exercise
      def update(exercise:, replace_questions:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # Pose published_at ou archived_at. → true
      def transition(id:, to:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #transition"
      end

      # → Boolean
      def has_sessions?(exercise_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #has_sessions?"
      end

      # Clés de doublon de l'import, pour les fiches données ou toutes.
      # → Set[[essential_id, Entities::Shared::NaturalKey.normalize(title)]]
      def existing_keys(essential_ids: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #existing_keys"
      end

      # Prochaine position libre par fiche. → { essential_id => Integer }
      def next_positions(essential_ids:)
        raise NotImplementedError, "#{self.class} doit implémenter #next_positions"
      end

      # Publication en cascade : public_id des exercices brouillon sous les fiches publiées d'un cours (course_id:) ou
      # sous une fiche (essential_id:), dans l'ordre des fiches puis des exercices. → [String]
      def draft_public_ids(course_id: nil, essential_id: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #draft_public_ids"
      end
    end
  end
end
