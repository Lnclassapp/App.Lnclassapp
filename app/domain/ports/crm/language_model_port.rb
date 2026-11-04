# 🧠 DOMAINE · Ports::Crm::LanguageModelPort
# Rôle : contrat d'un modèle de langage : une seule méthode, jamais appelée depuis une requête web
# ADR  : XXXX (modèles de langage) · gelé par le Lot 0
module Ports
  module Crm
    module LanguageModelPort
      # messages : [{ role: "system"|"user", content: String }] ; audio : { data: String (octets), format: "webm"|"ogg"|"mp4" } | nil
      # → Result({ text:, model:, input_tokens:, output_tokens:, duration_ms: }) | failure(:unavailable, errors: { reason: :not_configured | :timeout | :provider_error | :invalid_response })
      # (Shared::Result::ERROR_CODES est une liste fermée : la raison de l'échec voyage dans errors[:reason])
      def complete(messages:, model:, max_tokens:, json: false, audio: nil)
        raise NotImplementedError, "#{self.class} doit implémenter #complete"
      end
    end
  end
end
