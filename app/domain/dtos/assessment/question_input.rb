# 🧠 DOMAINE · Dtos::Assessment::QuestionInput
# Rôle : une question saisie : énoncé, explication, type, marge, éléments et image ; la structure par type reste à l'entité Question
# ADR  : 0026, 0054, 0091, 0105 · UDR : 0007, 0017, 0087, 0129
module Dtos
  module Assessment
    class QuestionInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :content, :string
      attribute :explanation, :string
      attribute :question_type, :string
      # Saisie libre (« 0,1 ») : lue comme un nombre par QuestionKinds::Numeric.parse, vide pour la valeur exacte.
      attribute :numeric_tolerance, :string
      # ADR-0105 : l'image envoyée (son public_id), son texte de remplacement, et l'image annoncée par l'import.
      attribute :image_public_id, :string
      attribute :image_alt, :string
      attribute :image_description, :string
      attr_writer :answers

      validates :content, presence: true
      validates :question_type, inclusion: { in: Entities::Assessment::Question::TYPES }
      validates :image_alt, :image_description, length: { maximum: Entities::Shared::ContentImage::ALT_MAX }
      validate :answers_must_be_valid
      validate :numeric_tolerance_must_be_a_number

      # fields_for envoie des éléments indexés ({ "0" => {…} }) ; un tableau est lu de la même façon.
      def self.list_from(value)
        items = value.respond_to?(:values) ? value.values : Array(value)
        items.map { yield it }
      end

      def self.from_params(hash)
        new(content: hash[:content], explanation: hash[:explanation], question_type: hash[:question_type],
            numeric_tolerance: hash[:numeric_tolerance],
            image_public_id: hash[:image_public_id], image_alt: hash[:image_alt], image_description: hash[:image_description],
            answers_attributes: hash[:answers_attributes])
      end

      def self.from_question(question)
        new(content: question.content, explanation: question.explanation, question_type: question.question_type,
            numeric_tolerance: question.numeric_tolerance&.to_s("F"),
            image_public_id: question.image&.public_id, image_alt: question.image&.alt, image_description: question.image_description,
            answers: question.answers.map { AnswerInput.new(content: it.content, correct: it.correct, match_content: it.match_content) })
      end

      def answers = @answers || []

      # fields_for :answers nomme ses champs answers_attributes[i] parce que ce writer existe.
      def answers_attributes=(value)
        @answers = QuestionInput.list_from(value) { AnswerInput.from_params(it) }
      end

      def content = super.to_s.strip
      def explanation = super.to_s.strip.presence
      def numeric_tolerance = super.to_s.strip.presence
      def image_public_id = super.to_s.strip.presence
      def image_alt = super.to_s.strip
      def image_description = super.to_s.strip.presence

      def to_entity(position:)
        Entities::Assessment::Question.new(
          id: nil, position:, content:, explanation:, question_type:, image_description:,
          numeric_tolerance: numeric_tolerance && Entities::Assessment::QuestionKinds::Numeric.parse(numeric_tolerance),
          image: image_public_id && Entities::Shared::ContentImage.new(public_id: image_public_id, alt: image_alt),
          answers: answers.each_with_index.map { |answer, index| answer.to_entity(position: index + 1) }
        )
      end

      private

      def answers_must_be_valid
        errors.add(:answers, :invalid) unless answers.map(&:valid?).all?
      end

      def numeric_tolerance_must_be_a_number
        return if numeric_tolerance.nil? || Entities::Assessment::QuestionKinds::Numeric.parse(numeric_tolerance)

        errors.add(:numeric_tolerance, :not_a_number)
      end
    end
  end
end
