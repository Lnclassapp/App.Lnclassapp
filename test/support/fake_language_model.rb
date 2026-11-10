# Modèle de langage factice (ADR-XXXX modèles de langage) : implémente Ports::Crm::LanguageModelPort sans jamais toucher le réseau.
# Réponses programmées (file, la dernière se répète), échec simulé par raison du port (:not_configured, :timeout, :provider_error, :invalid_response), appels gardés pour les assertions.
#
#   model = FakeLanguageModel.new("Fiche de briefing")
#   model.fail_with(:timeout)      # les appels suivants échouent : failure(:unavailable, errors: { reason: :timeout })
#   model.calls.last[:messages]    # ce que l'assistant a envoyé
class FakeLanguageModel
  include Ports::Crm::LanguageModelPort

  attr_reader :calls

  def initialize(*texts, model: "fake/model", input_tokens: 10, output_tokens: 20, duration_ms: 5)
    @texts = texts.presence || [ "Réponse simulée" ]
    @usage = { model:, input_tokens:, output_tokens:, duration_ms: }
    @failure = nil
    @calls = []
  end

  def respond_with(*texts)
    @failure = nil
    @texts = texts
    self
  end

  def fail_with(reason)
    @failure = reason
    self
  end

  def complete(messages:, model:, max_tokens:, json: false, audio: nil)
    @calls << { messages:, model:, max_tokens:, json:, audio: }
    return Shared::Result.failure(:unavailable, errors: { reason: @failure }) if @failure

    text = @texts.size > 1 ? @texts.shift : @texts.first
    Shared::Result.success({ text:, **@usage, model: model || @usage[:model] })
  end
end
