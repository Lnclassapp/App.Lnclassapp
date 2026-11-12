# 🔌 INFRA · Crm::WhatsappDraftJob
# Rôle : rédige le brouillon de relance WhatsApp : envoie la relance et les derniers échanges (sans nom d'élève, de contact ni numéro) au modèle de texte, garde 600 caractères au plus
# ADR  : XXXX (modèles de langage) · UDR : XXXX (assistants du suivi) · base : Crm::GenerationJob
module Crm
  class WhatsappDraftJob < GenerationJob
    MAX_TOKENS = 300

    private

    def messages(generation) = Queries::Crm::WhatsappDraftInputsQuery.new.call(id: generation.follow_up_id).messages

    def model_name = Rails.configuration.x.language_models.model_text

    def max_tokens = MAX_TOKENS

    # Une réponse vide n'est pas un message : l'exception devient un échec « invalid_response » (voir GenerationJob) que l'utilisateur peut réessayer.
    def content_for(text)
      Entities::Crm::WhatsappDraftPrompt.compose(text) || raise(ArgumentError, "brouillon WhatsApp vide")
    end
  end
end
