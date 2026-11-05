# 🔌 INFRA · Crm::BriefingJob
# Rôle : prépare la fiche de briefing d'une école : envoie les faits (sans nom d'élève) au modèle de texte, garde 5 lignes au plus
# ADR  : XXXX (modèles de langage) · UDR : XXXX (assistants du suivi) · base : Crm::GenerationJob
module Crm
  class BriefingJob < GenerationJob
    MAX_TOKENS = 400

    private

    def messages(generation) = Queries::Crm::BriefingInputsQuery.new.call(school_id: generation.school_id).messages

    def model_name = Rails.configuration.x.language_models.model_text

    def max_tokens = MAX_TOKENS

    # Une réponse vide n'est pas une fiche : l'exception devient un échec « invalid_response » (voir GenerationJob) que l'utilisateur peut réessayer.
    def content_for(text)
      Entities::Crm::BriefingPrompt.summarize(text) || raise(ArgumentError, "fiche de briefing vide")
    end
  end
end
