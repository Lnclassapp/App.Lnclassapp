# 🧠 DOMAINE · Dtos::Assessment::OfflineCopyInput
# Rôle : une copie rendue hors ligne, telle que l'appareil l'envoie : UUID, jeton du paquet, heures ISO 8601, réponses ; aucune note n'y entre
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.5, menace R1, R2, R5) · réponses lues par CopyInput
module Dtos
  module Assessment
    class OfflineCopyInput
      include ActiveModel::Model

      UUID_V4 = /\A\h{8}-\h{4}-4\h{3}-[89abAB]\h{3}-\h{12}\z/
      TOKEN_MAX = 2_000

      attr_reader :client_copy_id, :exercise_public_id, :pack_token, :started_at, :submitted_at, :answers

      validates :exercise_public_id, presence: true
      validates :client_copy_id, format: { with: UUID_V4 }
      validate :token_readable, :times_readable, :answers_readable

      # La charge est lue champ par champ : une clé de plus (score, provisional_percent, status…) est ignorée, jamais lue.
      def initialize(client_copy_id: nil, exercise_public_id: nil, pack_token: nil, started_at: nil, submitted_at: nil, answers: {}, **)
        super()
        @client_copy_id = client_copy_id.is_a?(String) ? client_copy_id : nil
        @exercise_public_id = exercise_public_id.is_a?(String) ? exercise_public_id : nil
        @pack_token = pack_token.is_a?(String) ? pack_token : nil
        @started_at = parse_time(started_at)
        @submitted_at = parse_time(submitted_at)
        @answers = answers
      end

      # Les réponses, lues comme une copie en ligne (100 au plus, AttemptInput) ; la validité de ce CopyInput est celle des réponses.
      def to_copy_input(session_public_id:) = CopyInput.new(session_public_id:, answers:)

      private

      def token_readable
        errors.add(:pack_token, :invalid) unless pack_token.present? && pack_token.length <= TOKEN_MAX
      end

      def answers_readable
        errors.add(:answers, :invalid) unless to_copy_input(session_public_id: "offline").valid?
      end

      def times_readable
        errors.add(:started_at, :invalid) if started_at.nil?
        errors.add(:submitted_at, :invalid) if submitted_at.nil?
      end

      def parse_time(value)
        return nil unless value.is_a?(String) && value.valid_encoding? && value.length <= 40

        Time.iso8601(value).utc
      rescue ArgumentError
        nil
      end
    end
  end
end
