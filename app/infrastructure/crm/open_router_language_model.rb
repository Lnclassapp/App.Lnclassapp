# 🔌 INFRA · Crm::OpenRouterLanguageModel
# Rôle : squelette du Lot 0 (adaptateur de Ports::Crm::LanguageModelPort), complété par le Lot G
# ADR  : XXXX (modèles de langage)
module Crm
  class OpenRouterLanguageModel
    include Ports::Crm::LanguageModelPort

    def complete(messages:, model:, max_tokens:, json: false, audio: nil)
      raise NotImplementedError, "Lot G"
    end
  end
end
