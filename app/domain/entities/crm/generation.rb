# 🧠 DOMAINE · Entities::Crm::Generation
# Rôle : une génération d'un modèle de langage (briefing, dictée, brouillon, rapport) : état, résultat, modèle, jetons, durée
# ADR  : XXXX (modèles de langage)
module Entities
  module Crm
    Generation = Data.define(:public_id, :school_id, :kind, :status, :requested_by_id, :follow_up_id, :input_fingerprint, :content,
                             :error_code, :model, :input_tokens, :output_tokens, :duration_ms, :created_at) do
      # created_at est facultatif à la construction (une génération pas encore écrite n'a pas d'instant) : les appels existants restent valides.
      def initialize(created_at: nil, **attributes) = super
      def pending? = status == "pending"
      def done? = status == "done"
      def failed? = status == "failed"
    end
    Generation::KINDS = %w[briefing dictation whatsapp_draft pedagogy_report].freeze
    Generation::STATUSES = %w[pending done failed].freeze
    Generation::ERROR_CODES = %w[not_configured timeout provider_error invalid_response].freeze
  end
end
