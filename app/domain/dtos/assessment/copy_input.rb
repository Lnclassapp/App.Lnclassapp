# 🧠 DOMAINE · Dtos::Assessment::CopyInput
# Rôle : la copie rendue par l'élève : une réponse par question (AttemptInput) ou nil quand elle est laissée vide
# ADR  : 0054, 0091 (§4.4 : jamais d'identifiant pour l'ordre et relier), 0112 · UDR : 0138
module Dtos
  module Assessment
    class CopyInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Une copie n'a jamais plus de réponses que cette borne ; le use case la compare au nombre réel de questions.
      MAX_ANSWERS = 100
      FIELDS = %i[answer_ids response_text display_order].freeze
      INTEGER = AttemptInput::INTEGER

      attribute :session_public_id, :string

      validates :session_public_id, presence: true
      validate :answers_readable

      # raw : { "<question_id>" => { answer_ids: [], response_text: "", display_order: [] } } tel que posté.
      def initialize(session_public_id: nil, answers: {})
        super(session_public_id:)
        self.answers = answers
      end

      # { question_id => AttemptInput | nil } ; nil : la question est restée vide (texte vide, rien coché, aucun indice).
      attr_reader :answers

      def answers=(raw)
        @answers = {}
        @unreadable = !raw.respond_to?(:each_pair) || raw.size > MAX_ANSWERS
        return if @unreadable

        raw.each_pair do |key, fields|
          @unreadable = true unless key.to_s.match?(INTEGER)
          next unless key.to_s.match?(INTEGER)

          @answers[key.to_s.to_i] = entry(key.to_s.to_i, fields)
        end
      end

      private

      def answers_readable
        errors.add(:answers, :invalid) if @unreadable
      end

      def entry(question_id, fields)
        fields = fields.is_a?(Hash) ? fields.symbolize_keys.slice(*FIELDS) : {}
        return if blank_fields?(fields)

        AttemptInput.new(session_public_id:, question_id:, **fields)
      end

      # Rien cochée, texte vide, aucun indice d'affichage choisi (relier : « Choisis… » partout) → question vide.
      def blank_fields?(fields)
        Array(fields[:answer_ids]).all? { it.to_s.strip.empty? } && fields[:response_text].to_s.strip.empty? &&
          Array(fields[:display_order]).all? { it.to_s.strip.empty? }
      end
    end
  end
end
