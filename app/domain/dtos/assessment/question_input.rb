# 🧠 DOMAINE · Dtos::Assessment::QuestionInput
# Rôle : une question saisie : énoncé, explication, type, propositions et image ; la structure par type reste à l'entité Question
# ADR  : 0026, 0054, 0089 · UDR : 0007, 0017, 0084
module Dtos
  module Assessment
    class QuestionInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :content, :string
      attribute :explanation, :string
      attribute :question_type, :string
      # ADR-0089 : l'image envoyée (son public_id), son texte de remplacement, et l'image annoncée par l'import.
      attribute :image_public_id, :string
      attribute :image_alt, :string
      attribute :image_description, :string
      attr_writer :answers

      validates :content, presence: true
      validates :question_type, inclusion: { in: Entities::Assessment::Question::TYPES }
      validates :image_alt, :image_description, length: { maximum: Entities::Shared::ContentImage::ALT_MAX }
      validate :answers_must_be_valid

      # fields_for envoie des éléments indexés ({ "0" => {…} }) ; un tableau est lu de la même façon.
      def self.list_from(value)
        items = value.respond_to?(:values) ? value.values : Array(value)
        items.map { yield it }
      end

      def self.from_params(hash)
        new(content: hash[:content], explanation: hash[:explanation], question_type: hash[:question_type],
            image_public_id: hash[:image_public_id], image_alt: hash[:image_alt], image_description: hash[:image_description],
            answers_attributes: hash[:answers_attributes])
      end

      def self.from_question(question)
        new(content: question.content, explanation: question.explanation, question_type: question.question_type,
            image_public_id: question.image&.public_id, image_alt: question.image&.alt, image_description: question.image_description,
            answers: question.answers.map { AnswerInput.new(content: it.content, correct: it.correct) })
      end

      def answers = @answers || []

      # fields_for :answers nomme ses champs answers_attributes[i] parce que ce writer existe.
      def answers_attributes=(value)
        @answers = QuestionInput.list_from(value) { AnswerInput.from_params(it) }
      end

      def content = super.to_s.strip
      def explanation = super.to_s.strip.presence
      def image_public_id = super.to_s.strip.presence
      def image_alt = super.to_s.strip
      def image_description = super.to_s.strip.presence

      def to_entity(position:)
        Entities::Assessment::Question.new(
          id: nil, position:, content:, explanation:, question_type:, image_description:,
          image: image_public_id && Entities::Shared::ContentImage.new(public_id: image_public_id, alt: image_alt),
          answers: answers.each_with_index.map { |answer, index| answer.to_entity(position: index + 1) }
        )
      end

      private

      def answers_must_be_valid
        errors.add(:answers, :invalid) unless answers.map(&:valid?).all?
      end
    end
  end
end
