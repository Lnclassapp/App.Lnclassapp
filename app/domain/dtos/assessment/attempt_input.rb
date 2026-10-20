# 🧠 DOMAINE · Dtos::Assessment::AttemptInput
# Rôle : réponse d'un élève à une question : propositions cochées, texte saisi, ou indices d'affichage (ordre, relier)
# ADR  : 0026, 0054, 0091 (§4.4 : jamais d'identifiant pour l'ordre et relier) · UDR : 0007, 0022, 0087
module Dtos
  module Assessment
    class AttemptInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      INTEGER = /\A\d+\z/
      # Borne de la colonne question_attempts.response_text.
      RESPONSE_TEXT_MAX = 200

      attribute :session_public_id, :string
      attribute :question_id, :integer

      validates :session_public_id, :question_id, presence: true
      # Une question à cocher n'envoie que answer_ids ; les trous et le nombre, response_text ; l'ordre et relier, display_order.
      validates :answer_ids, presence: true, if: -> { response_text.nil? && display_order.empty? }
      validates :response_text, presence: true, length: { maximum: RESPONSE_TEXT_MAX }, unless: -> { response_text.nil? }
      # PostgreSQL refuse l'octet nul dans un texte : refusé ici, en 422, plutôt qu'en erreur de la base.
      validates :response_text, format: { without: /\0/ }, unless: -> { response_text.nil? }

      # Cases à cocher et boutons radio envoient attempt[answer_ids][] ; une valeur seule se lit comme une liste.
      def answer_ids=(value)
        @answer_ids = Array(value).map(&:to_s).grep(INTEGER).map(&:to_i).uniq
      end

      def answer_ids = @answer_ids || []

      # nil quand le champ n'est pas posté : seule une question à texte l'envoie, même vide.
      def response_text=(value)
        @response_text = value.nil? ? nil : value.to_s.strip
      end

      attr_reader :response_text

      # attempt[display_order][] : l'ordre compte, et une valeur illisible reste, pour que la liste soit refusée entière.
      def display_order=(value)
        @display_order = Array(value).map { it.to_s.match?(INTEGER) ? it.to_i : -1 }
      end

      def display_order = @display_order || []
    end
  end
end
