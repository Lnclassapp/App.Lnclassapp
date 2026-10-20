# 🧠 DOMAINE · Dtos::Assessment::AnswerInput
# Rôle : un élément saisi dans le formulaire d'exercice : son texte (500 caractères), la case « correcte », le côté droit d'une paire
# ADR  : 0026, 0054, 0091 · UDR : 0007, 0017, 0087
module Dtos
  module Assessment
    class AnswerInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Borne de la colonne answers.content.
      CONTENT_MAX = 500

      attribute :content, :string
      attribute :correct, :boolean, default: false
      attribute :match_content, :string

      validates :content, presence: true, length: { maximum: CONTENT_MAX }
      validates :match_content, length: { maximum: CONTENT_MAX }

      # Un élément de answers_attributes : { content:, correct: "1" | "0", match_content: }.
      def self.from_params(hash) = new(content: hash[:content], correct: hash[:correct], match_content: hash[:match_content])

      def content = super.to_s.strip
      def match_content = super.to_s.strip.presence

      def to_entity(position:) = Entities::Assessment::Answer.new(id: nil, position:, content:, correct:, match_content:)
    end
  end
end
