# 🔌 INFRA · Crm::GenerationJob
# Rôle : classe de base des assistants : appelle le modèle hors requête web, enregistre texte, modèle, jetons et durée (ou le code d'échec), purge l'audio
# ADR  : XXXX (modèles de langage) · une sous-classe (Lots H-K) fournit `messages`, `max_tokens`, `model_name` et, si besoin, `json?`
module Crm
  class GenerationJob < ApplicationJob
    discard_on ActiveJob::DeserializationError

    AUDIO_FORMATS = { "audio/webm" => "webm", "audio/ogg" => "ogg", "audio/mp4" => "mp4" }.freeze

    # Panne du fournisseur : l'adaptateur la rend en échec, jamais en exception. Une exception ici est donc un bug du code :
    # la génération est fermée (`provider_error`), l'exception est journalisée sans le contenu du prompt, puis relancée pour Solid Queue.
    def perform(public_id)
      original = nil
      begin
        process(public_id)
      rescue StandardError => error
        original = error
        raise
      ensure
        purge_audio(public_id, original:)
      end
    end

    private

    def process(public_id)
      generation = repository.find_by_public_id(public_id:)
      return if generation.nil? || !generation.pending?

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      begin
        prompt = prompt_for(generation)
        return repository.mark_failed(public_id:, error_code: "invalid_response", duration_ms: elapsed_ms(started)) if prompt.nil?

        result = language_model.complete(messages: prompt, model: model_name, max_tokens:, json: json?, audio: audio_for(public_id))
        finish(generation, result, elapsed_ms(started))
      rescue StandardError => error
        log_bug(public_id, error)
        close_as_failed(public_id, elapsed_ms(started))
        raise
      end
    end

    # Le cas voulu « rien à générer » (ArgumentError de `messages`, ex. école sans activité) → nil : réponse inutilisable, sans relance.
    def prompt_for(generation)
      messages(generation)
    rescue ArgumentError
      nil
    end

    # Ni le prompt ni le corps de la réponse : la classe, le message d'erreur et la première ligne de la pile.
    def log_bug(public_id, error)
      Rails.logger.error("[crm.generation] #{self.class.name} #{public_id} : #{error.class}: #{error.message} (#{error.backtrace&.first})")
    end

    def close_as_failed(public_id, duration_ms)
      repository.mark_failed(public_id:, error_code: "provider_error", duration_ms:)
    rescue StandardError => error
      Rails.logger.error("[crm.generation] #{public_id} : mark_failed impossible (#{error.class})")
    end

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
        content = readable_content(value[:text])
        return repository.mark_failed(public_id: generation.public_id, error_code: "invalid_response", duration_ms:) if content.nil?

        repository.complete(public_id: generation.public_id, content:, model: value[:model],
                            input_tokens: value[:input_tokens], output_tokens: value[:output_tokens], duration_ms: value[:duration_ms])
      else
        reason = result.errors[:reason].to_s
        reason = "provider_error" unless Entities::Crm::Generation::ERROR_CODES.include?(reason)
        repository.mark_failed(public_id: generation.public_id, error_code: reason, duration_ms:)
      end
    end

    # Une réponse vide, ou que la sous-classe refuse de lire (content_for lève une exception), est une `invalid_response`.
    def readable_content(text)
      return nil if text.to_s.strip.empty?

      content_for(text).presence
    rescue ArgumentError
      nil
    end

    def audio_for(public_id)
      attachment = Orm::CrmGeneration.find_by(public_id:)&.audio
      return unless attachment&.attached?

      { data: attachment.download, format: AUDIO_FORMATS.fetch(attachment.content_type) }
    end

    # Purgé en succès, en échec et quand la génération n'est plus en attente : l'enregistrement ne reste jamais après le job.
    # Une purge qui échoue est journalisée (public_id) puis relancée, sauf si une exception d'origine est déjà en route (elle prime).
    def purge_audio(public_id, original: nil)
      attachment = Orm::CrmGeneration.find_by(public_id:)&.audio
      attachment.purge if attachment&.attached?
    rescue StandardError => error
      Rails.logger.error("[crm.generation] purge de l'audio impossible #{public_id} : #{error.class}")
      raise error if original.nil?
    end

    def elapsed_ms(started) = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
  end
end
