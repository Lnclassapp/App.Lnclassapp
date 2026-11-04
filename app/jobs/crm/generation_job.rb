# 🔌 INFRA · Crm::GenerationJob
# Rôle : classe de base des assistants : appelle le modèle hors requête web, enregistre texte, modèle, jetons et durée (ou le code d'échec), purge l'audio
# ADR  : XXXX (modèles de langage) · une sous-classe (Lots H-K) fournit `messages`, `max_tokens`, `model_name` et, si besoin, `json?`
module Crm
  class GenerationJob < ApplicationJob
    discard_on ActiveJob::DeserializationError

    AUDIO_FORMATS = { "audio/webm" => "webm", "audio/ogg" => "ogg", "audio/mp4" => "mp4" }.freeze

    def perform(public_id)
      generation = repository.find_by_public_id(public_id:)
      return if generation.nil? || !generation.pending?

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        result = language_model.complete(messages: messages(generation), model: model_name, max_tokens:, json: json?, audio: audio_for(public_id))
        finish(generation, result, elapsed_ms(started))
      rescue StandardError => error
        Rails.logger.error("[crm.generation] #{self.class.name} #{public_id} : #{error.class}")
        repository.mark_failed(public_id:, error_code: "provider_error", duration_ms: elapsed_ms(started))
      ensure
        purge_audio(public_id)
      end
    end

    private

    def repository = @repository ||= Repositories::Crm::GenerationRepository.new

    def language_model = Crm::OpenRouterLanguageModel.new

    def messages(_generation) = raise(NotImplementedError, "#{self.class} doit définir #messages")
    def model_name = raise(NotImplementedError, "#{self.class} doit définir #model_name")
    def max_tokens = raise(NotImplementedError, "#{self.class} doit définir #max_tokens")
    def json? = false

    # Le texte du modèle devient le contenu stocké ; une sous-classe peut le valider ou le restructurer.
    def content_for(text) = text

    def finish(generation, result, duration_ms)
      if result.success?
        value = result.value
        repository.complete(public_id: generation.public_id, content: content_for(value[:text]), model: value[:model],
                            input_tokens: value[:input_tokens], output_tokens: value[:output_tokens], duration_ms: value[:duration_ms])
      else
        reason = result.errors[:reason].to_s
        reason = "provider_error" unless Entities::Crm::Generation::ERROR_CODES.include?(reason)
        repository.mark_failed(public_id: generation.public_id, error_code: reason, duration_ms:)
      end
    end

    def audio_for(public_id)
      attachment = Orm::CrmGeneration.find_by(public_id:)&.audio
      return unless attachment&.attached?

      { data: attachment.download, format: AUDIO_FORMATS.fetch(attachment.content_type, "webm") }
    end

    # Purgé en succès comme en échec : l'enregistrement ne reste jamais après le job.
    def purge_audio(public_id)
      attachment = Orm::CrmGeneration.find_by(public_id:)&.audio
      attachment.purge if attachment&.attached?
    end

    def elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end
end
