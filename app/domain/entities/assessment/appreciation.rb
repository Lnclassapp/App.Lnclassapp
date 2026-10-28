# 🧠 DOMAINE · Entities::Assessment::Appreciation
# Rôle : l'appréciation d'un professeur sur une copie vérifiée (« Très bien » à « À retravailler ») et ce qu'il faut revoir
# ADR  : 0106 (la note sur 20 affichée fait foi), 0115 (§4 ; PRD §3 : une réponse rédigée ou un cahier n'est jamais en cause)
module Entities
  module Assessment
    # level : :very_good | :good | :fair | :needs_work ; grade : la note sur 20 affichée.
    # weak_numbers : les numéros des questions en cause, croissants ; scope : :essential (exercice de notion, essential_name la
    # nomme) ou :lesson (exercice de toute la leçon, aucune notion nommée).
    Appreciation = Data.define(:level, :grade, :weak_numbers, :scope, :essential_name) do
      # outcomes : [[numéro de la question, corrigée automatiquement, juste]] de toutes les questions de l'exercice.
      # Une question est en cause si elle est corrigée automatiquement et fausse ou sans réponse.
      def self.for(score_percent:, outcomes:, essential_name: nil)
        grade = Grading.grade_on_20(score_percent)
        level = Appreciation::LEVELS.find { |_, threshold| grade >= threshold }&.first || :needs_work
        weak = outcomes.select { |_, auto_graded, correct| auto_graded && !correct }.map(&:first).sort
        new(level:, grade:, weak_numbers: weak, scope: (essential_name ? :essential : :lesson), essential_name:)
      end

      def review? = weak_numbers.any?
    end
    # Seuils sur la note sur 20 affichée : 16, 12 et 10 (79 %, affiché 16/20, est « Très bien »).
    Appreciation::LEVELS = { very_good: 16, good: 12, fair: 10 }.freeze
  end
end
