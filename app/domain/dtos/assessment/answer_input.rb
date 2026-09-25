# 🧠 DOMAINE · Dtos::Assessment::AnswerInput
# Rôle : une proposition saisie dans le formulaire d'exercice : son texte (500 caractères) et la case « correcte »
# ADR  : 0026, 0054 · UDR : 0007, 0017
module Dtos
  module Assessment
    class AnswerInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Borne de la colonne answers.content.
      CONTENT_MAX = 500

      attribute :content, :string
      attribute :correct, :boolean, default: false

      validates :content, presence: true, length: { maximum: CONTENT_MAX }

      # Un élément de answers_attributes : { content:, correct: "1" | "0" }.
      def self.from_params(hash) = new(content: hash[:content], correct: hash[:correct])

      def content = super.to_s.strip

      def to_entity(position:) = Entities::Assessment::Answer.new(id: nil, position:, content:, correct:)
    end
  end
end
