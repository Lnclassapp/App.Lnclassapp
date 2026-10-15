# 🧠 DOMAINE · Entities::Assessment::AnswerShuffle
# Rôle : ordre d'affichage des éléments d'une question, propre à la session, et lecture des indices d'affichage postés
# ADR  : 0054 (AS-09), 0091 (§4.4 : gelé, la reprise d'une session ouverte en dépend)
module Entities
  module Assessment
    module AnswerShuffle
      # Gelé : les identifiants triés, mélangés par la graine session_id ^ question_id, exactement comme le faisait
      # SessionPlayQuery avant l'ADR-0091. Le changer fausserait la correction des sessions déjà ouvertes.
      def self.for(session_id:, question_id:, ids:) = ids.sort.shuffle(random: Random.new(session_id ^ question_id))

      # indices : indices d'affichage postés (attempt[display_order][]). Une permutation de 0...n rend les identifiants
      # dans l'ordre de l'élève ; toute autre liste (manquant, doublon, hors bornes) rend [], une réponse mal formée.
      def self.pick(shuffled_ids, indices)
        return [] unless indices.sort == (0...shuffled_ids.size).to_a

        indices.map { shuffled_ids.fetch(it) }
      end
    end
  end
end
