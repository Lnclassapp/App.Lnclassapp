# 🧠 DOMAINE · Entities::Crm::DictationDraft
# Rôle : le brouillon de « Noter un échange » tiré de la réponse du modèle, sous un schéma fermé ; toute autre réponse devient la seule transcription dans la note
# ADR  : XXXX (modèles de langage, menace du compte rendu dicté : schéma fermé, texte toujours échappé) · UDR : XXXX (assistants du suivi) · CA-27
require "json"

module Entities
  module Crm
    # structured : faux quand la réponse n'a pas pu être lue (seule la note est remplie, avec le texte brut).
    DictationDraft = Data.define(:kind, :outcome, :contact_name, :next_step, :note, :follow_up_in_days, :structured) do
      # La réponse du modèle (texte) → brouillon. Jamais d'exception : une réponse inexploitable retombe sur la transcription.
      def self.parse(text)
        hash = decode(text)
        from_hash(hash) || transcription(hash.is_a?(Hash) ? hash["transcription"] || hash["note"] : nil, text)
      end

      # Le contenu stocké dans la génération (voir #to_content) → brouillon.
      def self.from_content(content)
        hash = decode(content)
        return transcription(nil, content) unless hash.is_a?(Hash)
        return transcription(hash["note"], content) if hash["structured"] == false

        from_hash(hash.except("structured")) || transcription(nil, content)
      end

      def to_content = JSON.generate(to_h.except(:structured).merge(structured:))

      def self.decode(text)
        body = text.to_s.strip.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      # Schéma fermé : clés connues, valeurs des listes du formulaire, longueurs du formulaire. → brouillon | nil
      def self.from_hash(hash)
        return nil unless hash.is_a?(Hash) && (hash.keys - DictationDraft::KEYS).empty?
        return nil unless DictationDraft::REQUIRED.all? { hash[it].is_a?(String) }

        draft = new(kind: hash["kind"], outcome: hash["outcome"], contact_name: hash["contact_name"], next_step: hash["next_step"],
                    note: hash["note"], follow_up_in_days: hash["follow_up_in_days"], structured: true)
        draft if draft.conforms?
      end

      # Le texte brut (ou le champ de texte d'une réponse hors schéma), sans balise ni caractère de contrôle, coupé à la longueur de la note.
      def self.transcription(preferred, raw)
        text = (preferred.is_a?(String) ? preferred : raw).to_s.gsub(/<[^>]*>/, "").gsub(/[[:cntrl:]&&[^\n\t]]/, "").strip
        new(kind: nil, outcome: nil, contact_name: nil, next_step: nil, note: text[0, Interaction::NOTE_MAX], follow_up_in_days: nil, structured: false)
      end

      def conforms?
        Interaction::KINDS.include?(kind) && Interaction::OUTCOMES.include?(outcome) &&
          text_within?(contact_name, Contact::NAME_MAX) && text_within?(next_step, Interaction::NEXT_STEP_MAX) &&
          text_within?(note, Interaction::NOTE_MAX, required: true) && follow_up_valid?
      end

      private

      def text_within?(value, max, required: false)
        return !required if value.nil?

        value.is_a?(String) && value.length <= max
      end

      def follow_up_valid?
        follow_up_in_days.nil? || (follow_up_in_days.is_a?(Integer) && DictationDraft::FOLLOW_UP_DAYS.cover?(follow_up_in_days))
      end
    end
    DictationDraft::KEYS = %w[kind outcome contact_name next_step note follow_up_in_days].freeze
    DictationDraft::REQUIRED = %w[kind outcome note].freeze
    DictationDraft::FOLLOW_UP_DAYS = (1..90)
  end
end
