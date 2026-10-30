# 🧠 DOMAINE · Dtos::Assessment::CopyInput
# Rôle : la copie rendue par l'élève : une réponse par question (AttemptInput) ou nil quand elle est laissée vide
# ADR  : 0054, 0091 (§4.4 : jamais d'identifiant pour l'ordre et relier), 0112, XXXX-questions-a-plusieurs-cases-et-indice (§4 : blanks) · UDR : 0138
module Dtos
  module Assessment
    class CopyInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      # Une copie n'a jamais plus de réponses que cette borne ; le use case la compare au nombre réel de questions.
      MAX_ANSWERS = 100
      FIELDS = %i[answer_ids response_text display_order blanks].freeze
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

      # Un texte aux octets invalides n'est pas vide : il va jusqu'à AttemptInput, qui le refuse (strip lèverait).
      def blank_text?(text) = text.to_s.then { it.valid_encoding? && it.strip.empty? }

      # Rien cochée, texte vide, aucun indice d'affichage choisi (relier : « Choisis… » partout) → question vide.
      def blank_fields?(fields)
        Array(fields[:answer_ids]).all? { it.to_s.strip.empty? } && blank_text?(fields[:response_text]) &&
          Array(fields[:display_order]).all? { it.to_s.strip.empty? } && blank_cases?(fields[:blanks])
      end

      # Aucune case remplie (ou choisie) : la question est vide. Une forme illisible n'est pas vide, AttemptInput la refuse.
      def blank_cases?(blanks)
        return true if blanks.nil?
        return false unless blanks.respond_to?(:each_pair) || blanks.is_a?(Array)

        (blanks.respond_to?(:each_pair) ? blanks.each_pair.map(&:last) : blanks).all? { it.is_a?(String) && blank_text?(it) }
      end
    end
  end
end
