# 🧠 DOMAINE · Entities::Assessment::Question
# Rôle : vérifie la forme d'une réponse, la corrige par identifiants et contrôle la structure d'une question
# ADR  : 0039, 0054
module Entities
  module Assessment
    # answers : [Answer]
    Question = Data.define(:id, :position, :content, :explanation, :question_type, :answers) do
      # Règles de l'ADR-0039 → [Symbol], vide si la question est bien construite.
      # answers : objets qui répondent à correct (Answer, ou proposition importée).
      def self.structure_errors_for(question_type:, answers:)
        expected = Question::EXPECTED[question_type.to_s.to_sym]
        return [ :unknown_question_type ] if expected.nil?

        errors = []
        errors << :true_false_needs_two_answers if question_type.to_s == "true_false" && answers.size != 2
        errors << :too_few_answers if answers.size < expected
        errors << :wrong_correct_count if answers.count(&:correct) != expected
        errors
      end

      def expected_count = Question::EXPECTED.fetch(question_type.to_s.to_sym)
      def answer_ids = answers.map(&:id)
      def correct_answer_ids = answers.select(&:correct).map(&:id)

      # Nombre attendu de propositions distinctes, toutes de cette question.
      def well_formed?(selected_ids)
        selected_ids.uniq.size == selected_ids.size && selected_ids.size == expected_count &&
          (selected_ids - answer_ids).empty?
      end

      # Égalité exacte des ensembles d'identifiants.
      def correct?(selected_ids) = selected_ids.sort == correct_answer_ids.sort

      def structure_errors = Question.structure_errors_for(question_type:, answers:)

      # Copie montrable avant une tentative : aucune proposition ne dit si elle est correcte.
      def without_correction = with(answers: answers.map { |answer| answer.with(correct: nil) })
    end
    Question::EXPECTED = { true_false: 1, single_choice: 1, multiple_correct_2: 2, multiple_correct_3: 3 }.freeze
    Question::TYPES = Question::EXPECTED.keys.map(&:to_s).freeze
  end
end
