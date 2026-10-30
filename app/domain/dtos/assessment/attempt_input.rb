# 🧠 DOMAINE · Dtos::Assessment::AttemptInput
# Rôle : réponse d'un élève à une question : propositions cochées, texte saisi, indices d'affichage (ordre, relier) ou une saisie par case
# ADR  : 0026, 0054, 0091 (§4.4 : jamais d'identifiant pour l'ordre et relier), 0115 (réponse rédigée, menace W2 à W4), XXXX-questions-a-plusieurs-cases-et-indice (§4 : blanks) · UDR : 0007, 0022, 0087
module Dtos
  module Assessment
    class AttemptInput
      include ActiveModel::Model
      include ActiveModel::Attributes

      INTEGER = /\A\d+\z/
      # Réponse courte (trous, nombre) : le use case la refuse au-delà. Réponse rédigée : borne de la colonne question_attempts.response_text.
      RESPONSE_TEXT_MAX = 200
      WRITTEN_TEXT_MAX = 2000
      # Au plus 6 cases par question (ADR cases §4), numérotées de 0 à 5.
      BLANKS_MAX = 6

      attribute :session_public_id, :string
      attribute :question_id, :integer

      validates :session_public_id, :question_id, presence: true
      # Une question à cocher n'envoie que answer_ids ; les trous et le nombre, response_text ; l'ordre et relier, display_order.
      validates :answer_ids, presence: true, if: -> { response_text.nil? && display_order.empty? && blanks.empty? }
      # Le DTO ne connaît pas le type de la question : il pose la borne la plus large (une réponse rédigée), le use case resserre.
      validates :response_text, presence: true, unless: -> { response_text.nil? || !response_text.valid_encoding? }
      # PostgreSQL refuse l'octet nul dans un texte : refusé ici, en 422, plutôt qu'en erreur de la base.
      validates :response_text, format: { without: /\0/ }, unless: -> { response_text.nil? || !response_text.valid_encoding? }
      validate :response_text_encoding, :response_text_length, :blanks_readable

      # Cases à cocher et boutons radio envoient attempt[answer_ids][] ; une valeur seule se lit comme une liste.
      def answer_ids=(value)
        @answer_ids = Array(value).map(&:to_s).grep(INTEGER).map(&:to_i).uniq
      end

      def answer_ids = @answer_ids || []

      # nil quand le champ n'est pas posté : seule une question à texte l'envoie, même vide.
      def response_text=(value)
        text = value.nil? ? nil : value.to_s
        # Un texte aux octets invalides ne se nettoie pas (strip lèverait) : il est gardé tel quel et refusé à la validation.
        # Le navigateur poste \r\n (2 caractères) là où maxlength et le compteur en comptent 1 : on compte comme eux.
        @response_text = text&.valid_encoding? ? text.gsub("\r\n", "\n").strip : text
      end

      attr_reader :response_text

      # attempt[display_order][] : l'ordre compte, et une valeur illisible reste, pour que la liste soit refusée entière.
      def display_order=(value)
        @display_order = Array(value).map { it.to_s.match?(INTEGER) ? it.to_i : -1 }
      end

      def display_order = @display_order || []

      # attempt[blanks][<i>] : la saisie de la case i (un texte, ou l'indice d'affichage d'une proposition), i de 0 à 5. Une liste de
      # textes, rangés par case, vides pour les cases sautées. Toute autre forme (case hors bornes, valeur qui n'est pas un texte,
      # plus de six cases) est gardée pour être refusée à la validation, sans rien lire de plus.
      def blanks=(value)
        pairs = if value.respond_to?(:each_pair) then value.each_pair.to_a
        elsif value.is_a?(Array) then value.each_with_index.map { |text, index| [ index, text ] }
        end
        @blanks_unreadable = pairs.nil? || pairs.size > BLANKS_MAX || pairs.any? { |key, text| !key.to_s.match?(INTEGER) || key.to_i >= BLANKS_MAX || !text.is_a?(String) }
        @blanks = @blanks_unreadable ? [] : pairs.each_with_object([]) { |(key, text), list| list[key.to_i] = clean(text) }.map { it || "" }
      end

      def blanks = @blanks || []

      private

      # Même nettoyage que response_text : \r\n compte pour un caractère, espaces de bord retirés (texte aux octets invalides gardé tel quel).
      def clean(text) = text.valid_encoding? ? text.gsub("\r\n", "\n").strip : text

      # Une case lit les mêmes bornes que response_text (réponse courte) ; l'erreur est celle de response_text, que l'écran sait dire.
      def blanks_readable
        return errors.add(:response_text, :invalid) if @blanks_unreadable

        errors.add(:response_text, :invalid) unless blanks.all? { it.valid_encoding? && !it.include?("\0") }
        errors.add(:response_text, :text_too_long, count: RESPONSE_TEXT_MAX) if blanks.any? { it.length > RESPONSE_TEXT_MAX }
      end

      def response_text_length
        errors.add(:response_text, :text_too_long, count: WRITTEN_TEXT_MAX) if response_text.to_s.length > WRITTEN_TEXT_MAX
      end

      def response_text_encoding
        errors.add(:response_text, :invalid) unless response_text.nil? || response_text.valid_encoding?
      end
    end
  end
end
