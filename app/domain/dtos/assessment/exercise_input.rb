# 🧠 DOMAINE · Dtos::Assessment::ExerciseInput
# Rôle : l'exercice saisi en modale, avec l'arbre de ses questions et propositions tiré de questions_attributes
# ADR  : 0026, 0054 · UDR : 0007, 0017
module Dtos
  module Assessment
    class ExerciseInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :title, :string
      attribute :description, :string
      attribute :exercise_type, :string
      attr_writer :questions

      # La longueur du titre est une règle de l'entité Exercise.
      validates :title, presence: true
      validates :exercise_type, inclusion: { in: Entities::Assessment::Exercise::TYPES }
      validate :questions_must_be_valid

      # hash : les paramètres du formulaire. Sans questions_attributes, l'exercice n'a aucune question.
      def self.from_params(hash)
        new(title: hash[:title], description: hash[:description], exercise_type: hash[:exercise_type],
            questions_attributes: hash[:questions_attributes])
      end

      # Formulaire d'édition rempli depuis l'exercice enregistré.
      def self.from_exercise(exercise)
        new(title: exercise.title, description: exercise.description, exercise_type: exercise.exercise_type,
            questions: exercise.questions.map { QuestionInput.from_question(it) })
      end

      def questions = @questions || []

      # fields_for :questions nomme ses champs questions_attributes[i] parce que ce writer existe.
      def questions_attributes=(value)
        @questions = QuestionInput.list_from(value) { QuestionInput.from_params(it) }
      end

      def title = super.to_s.squish
      def description = super.to_s.strip.presence

      # Questions et propositions numérotées dans l'ordre du formulaire.
      def question_entities = questions.each_with_index.map { |question, index| question.to_entity(position: index + 1) }

      # Une erreur de structure est posée sur « questions[i] », que ce formulaire n'a pas comme attribut à lire.
      def read_attribute_for_validation(attribute)
        return if attribute.to_s.include?("[")

        super
      end

      private

      def questions_must_be_valid
        errors.add(:questions, :invalid) unless questions.map(&:valid?).all?
      end
    end
  end
end
