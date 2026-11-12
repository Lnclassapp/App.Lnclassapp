# 🔌 INFRA · Crm::OpenRouterLanguageModel
# Rôle : adaptateur de Ports::Crm::LanguageModelPort sur l'API de chat compatible OpenAI d'OpenRouter (Net::HTTP, 5 s / 30 s, 90 s avec audio, sans nouvelle tentative)
# ADR  : XXXX (modèles de langage)
module Crm
  class OpenRouterLanguageModel
    include Ports::Crm::LanguageModelPort

    HOST = "openrouter.ai".freeze
    PATH = "/api/v1/chat/completions".freeze
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30
    # Une dictée dure jusqu'à 3 min : son traitement dépasse 30 s (mesuré le 2026-11-09 avec google/gemini-2.5-flash, échec à 31,7 s).
    # 90 s reste sous la péremption d'une génération en attente (2 min) et sous l'attente de la page pour une dictée (120 s).
    AUDIO_READ_TIMEOUT = 90
    # Une réponse de chat tient en quelques Ko : au-delà de 256 Ko, la réponse est refusée sans être lue en entier.
    MAX_BODY_BYTES = 256 * 1024
    Reply = Data.define(:code, :body)
    NETWORK_ERRORS = [ SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError ].freeze

    # Routage OpenRouter : seulement les fournisseurs qui ne conservent pas les données (`provider.data_collection: "deny"`).
    PROVIDER_PREFERENCES = { data_collection: "deny" }.freeze
    # Demande d'une réponse JSON (`response_format`, documentation OpenRouter).
    JSON_RESPONSE_FORMAT = { type: "json_object" }.freeze
    # À VÉRIFIER dans la documentation OpenRouter (réseau bloqué au Lot G) : forme d'une pièce audio dans un message
    # (`{ type: "input_audio", input_audio: { data: <base64>, format: } }`).
    AUDIO_PART_TYPE = "input_audio".freeze

    def initialize(api_key: Rails.configuration.x.language_models.api_key, http: Net::HTTP)
      @api_key = api_key
      @http = http
    end

    def complete(messages:, model:, max_tokens:, json: false, audio: nil)
      if @api_key.blank?
        Rails.logger.warn("[crm.openrouter] not_configured")
        return failure(:not_configured)
      end

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = post(payload(messages:, model:, max_tokens:, json:, audio:), read_timeout: audio ? AUDIO_READ_TIMEOUT : READ_TIMEOUT)
      unless response.code.start_with?("2")
        # Ni le corps, ni la clé, ni les messages : seulement le statut et le modèle.
        Rails.logger.warn("[crm.openrouter] status=#{response.code} model=#{model}")
        return failure(:provider_error)
      end
      if response.body.nil?
        Rails.logger.warn("[crm.openrouter] status=#{response.code} model=#{model} body_too_large")
        return failure(:invalid_response)
      end

      parse(response.body, model:, duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, Errno::ETIMEDOUT => error
      Rails.logger.warn("[crm.openrouter] timeout #{error.class} model=#{model}")
      failure(:timeout)
    rescue *NETWORK_ERRORS => error
      Rails.logger.warn("[crm.openrouter] network #{error.class} model=#{model}")
      failure(:provider_error)
    end

    private

    def failure(reason) = Shared::Result.failure(:unavailable, errors: { reason: })

    def post(body, read_timeout:)
      request = Net::HTTP::Post.new(PATH)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      reply = nil
      @http.start(HOST, 443, use_ssl: true, open_timeout: OPEN_TIMEOUT, read_timeout:) do |connection|
        connection.request(request) { |response| reply = Reply.new(code: response.code.to_s, body: read_capped(response)) }
      end
      reply
    end

    # Le corps n'est lu (par morceaux) que pour une réponse 2xx ; nil si le plafond est dépassé.
    def read_capped(response)
      return "" unless response.code.to_s.start_with?("2")

      body = +""
      response.read_body do |chunk|
        body << chunk
        return nil if body.bytesize > MAX_BODY_BYTES
      end
      body
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
    rescue JSON::ParserError, TypeError
      failure(:invalid_response)
    end
  end
end
