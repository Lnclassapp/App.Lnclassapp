# 🧠 DOMAINE · Dtos::Assessment::QuestionInput
# Rôle : une question saisie : énoncé, explication, type, marge, éléments et image ; la structure par type reste à l'entité Question
# ADR  : 0026, 0054, 0091, 0105, 0115 · UDR : 0007, 0017, 0087, 0129
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
      # ADR-0115 : points (« 2,5 », 1 sans saisie), unité d'un nombre, début de phrase et grille d'une réponse rédigée.
      attribute :points, :string
      attribute :unit, :string
      attribute :starter, :string
      attr_writer :answers, :criteria

      validates :content, presence: true
      validates :question_type, inclusion: { in: Entities::Assessment::Question::TYPES }
      validates :image_alt, :image_description, length: { maximum: Entities::Shared::ContentImage::ALT_MAX }
      validate :answers_must_be_valid
      validate :numeric_tolerance_must_be_a_number
      validate :points_must_be_a_number

      # fields_for envoie des éléments indexés ({ "0" => {…} }) ; un tableau est lu de la même façon.
      def self.list_from(value)
        items = value.respond_to?(:values) ? value.values : Array(value)
        items.map { yield it }
      end

      def self.from_params(hash)
        new(content: hash[:content], explanation: hash[:explanation], question_type: hash[:question_type],
            numeric_tolerance: hash[:numeric_tolerance],
            image_public_id: hash[:image_public_id], image_alt: hash[:image_alt], image_description: hash[:image_description],
            points: hash[:points], unit: hash[:unit], starter: hash[:starter], criteria: hash[:criteria],
            answers_attributes: hash[:answers_attributes])
      end

      def self.from_question(question)
        new(content: question.content, explanation: question.explanation, question_type: question.question_type,
            numeric_tolerance: question.numeric_tolerance&.to_s("F"),
            image_public_id: question.image&.public_id, image_alt: question.image&.alt, image_description: question.image_description,
            points: question.points.to_s("F"), unit: question.unit, starter: question.starter, criteria: question.criteria,
            answers: question.answers.map { AnswerInput.new(content: it.content, correct: it.correct, match_content: it.match_content) })
      end

      def answers = @answers || []
      def criteria = Array(@criteria).map { it.to_s.strip }.reject(&:empty?)

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
      def points = super.to_s.strip.presence
      def unit = super.to_s.strip.presence
      def starter = super.to_s.strip.presence

      def to_entity(position:)
        Entities::Assessment::Question.new(
          id: nil, position:, content:, explanation:, question_type:, image_description:, points: points_value, unit:, starter:, criteria:,
          numeric_tolerance: numeric_tolerance && Entities::Assessment::QuestionKinds::Numeric.parse(numeric_tolerance),
          image: image_public_id && Entities::Shared::ContentImage.new(public_id: image_public_id, alt: image_alt),
          answers: answers.each_with_index.map { |answer, index| answer.to_entity(position: index + 1) }
        )
      end

      private

      POINTS_FORMAT = /\A\d+(?:\.\d+)?\z/

      # Sans saisie, 1 point ; une saisie illisible vaut 0, que la structure de la question refuse (points_out_of_range).
      def points_value
        return BigDecimal("1") if points.nil?

        text = points.tr(",", ".")
        text.match?(POINTS_FORMAT) ? BigDecimal(text) : BigDecimal("0")
      end

      def points_must_be_a_number
        errors.add(:points, :not_a_number) unless points.nil? || points.tr(",", ".").match?(POINTS_FORMAT)
      end

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
