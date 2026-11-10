# 🔌 INFRA · Crm::PedagogyReportJob
# Rôle : rédige la synthèse du rapport pédagogique d'une école : envoie les agrégats sur 30 jours (jamais un nom d'élève) au modèle de texte
# ADR  : XXXX (modèles de langage) · UDR : XXXX (assistants du suivi) · base : Crm::GenerationJob
module Crm
  class PedagogyReportJob < GenerationJob
    MAX_TOKENS = 500

    private

    def messages(generation)
      prompt = Queries::Crm::PedagogyReportQuery.new.call(school_id: generation.school_id)
      raise ArgumentError, "école sans activité" if prompt.nil? || !prompt.activity?

      prompt.messages
    end

    def model_name = Rails.configuration.x.language_models.model_text

    def max_tokens = MAX_TOKENS

    # Une réponse vide n'est pas une synthèse : l'exception devient un échec « invalid_response » (voir GenerationJob).
    def content_for(text)
      Entities::Crm::PedagogyReportPrompt.summarize(text) || raise(ArgumentError, "synthèse vide")
    end
  end
end
