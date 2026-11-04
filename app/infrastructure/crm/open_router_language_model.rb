# 🔌 INFRA · Crm::OpenRouterLanguageModel
# Rôle : adaptateur de Ports::Crm::LanguageModelPort sur l'API de chat compatible OpenAI d'OpenRouter (Net::HTTP, 5 s / 30 s, sans nouvelle tentative)
# ADR  : XXXX (modèles de langage)
module Crm
  class OpenRouterLanguageModel
    include Ports::Crm::LanguageModelPort

    HOST = "openrouter.ai".freeze
    PATH = "/api/v1/chat/completions".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30
    NETWORK_ERRORS = [ SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError ].freeze

    # À VÉRIFIER dans la documentation OpenRouter (réseau bloqué au Lot G) : réglage de routage qui n'envoie les requêtes
    # qu'aux fournisseurs ne conservant pas les données (`provider.data_collection: "deny"`).
    PROVIDER_PREFERENCES = { data_collection: "deny" }.freeze
    # À VÉRIFIER dans la documentation OpenRouter (réseau bloqué au Lot G) : demande d'une réponse JSON (`response_format`).
    JSON_RESPONSE_FORMAT = { type: "json_object" }.freeze
    # À VÉRIFIER dans la documentation OpenRouter (réseau bloqué au Lot G) : forme d'une pièce audio dans un message
    # (`{ type: "input_audio", input_audio: { data: <base64>, format: } }`).
    AUDIO_PART_TYPE = "input_audio".freeze

    def initialize(api_key: Rails.configuration.x.language_models.api_key, http: Net::HTTP)
      @api_key = api_key
      @http = http
    end

    def complete(messages:, model:, max_tokens:, json: false, audio: nil)
      return failure(:not_configured) if @api_key.blank?

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = post(payload(messages:, model:, max_tokens:, json:, audio:))
      return failure(:provider_error) unless response.code.to_s.start_with?("2")

      parse(response.body, model:, duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
      failure(:timeout)
    rescue *NETWORK_ERRORS
      failure(:provider_error)
    end

    private

    def failure(reason) = Shared::Result.failure(:unavailable, errors: { reason: })

    def post(body)
      request = Net::HTTP::Post.new(PATH)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      @http.start(HOST, 443, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) { |connection| connection.request(request) }
    end

    def payload(messages:, model:, max_tokens:, json:, audio:)
      body = { model:, max_tokens:, messages: with_audio(messages, audio), provider: PROVIDER_PREFERENCES }
      body[:response_format] = JSON_RESPONSE_FORMAT if json
      body
    end

    # L'audio part avec le dernier message de l'utilisateur, tel quel (aucune lecture ni décodage côté serveur).
    def with_audio(messages, audio)
      return messages if audio.nil?

      messages.each_with_index.map do |message, index|
        next message unless index == messages.rindex { it[:role] == "user" }

        part = { type: AUDIO_PART_TYPE, AUDIO_PART_TYPE => { data: Base64.strict_encode64(audio[:data]), format: audio[:format] } }
        { **message, content: [ { type: "text", text: message[:content] }, part ] }
      end
    end

    def parse(body, model:, duration_ms:)
      data = JSON.parse(body.to_s)
      text = data.is_a?(Hash) ? data.dig("choices", 0, "message", "content") : nil
      return failure(:invalid_response) unless text.is_a?(String) && text.strip.present?

      usage = data["usage"].is_a?(Hash) ? data["usage"] : {}
      Shared::Result.success({ text:, model: data["model"].presence || model, input_tokens: usage["prompt_tokens"].to_i,
                               output_tokens: usage["completion_tokens"].to_i, duration_ms: })
    rescue JSON::ParserError, TypeError, NoMethodError
      failure(:invalid_response)
    end
  end
end
