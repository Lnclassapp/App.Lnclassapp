require "test_helper"

# ADR-XXXX (modèles de langage) §4 et §6: the adapter speaks the OpenAI-compatible chat API through an injected HTTP client
# (never the network), and maps every failure to a reason of the port: not_configured, timeout, provider_error, invalid_response.
module Crm
  class OpenRouterLanguageModelTest < ActiveSupport::TestCase
    # Like Net::HTTP::Response: the body is read in chunks by #read_body.
    Response = Struct.new(:code, :body) do
      def read_body(&) = body.to_s.scan(/.{1,65536}/m).each(&)
    end

    # Replaces Net::HTTP: records the request, answers a programmed response or raises a programmed error.
    class FakeHttp
      attr_reader :started_with, :request

      def initialize(response: nil, error: nil)
        @response, @error = response, error
      end

      def start(host, port, **options)
        @started_with = { host:, port:, **options }
        raise @error if @error

        owner = self
        connection = Object.new
        connection.define_singleton_method(:request) do |request, &block|
          owner.instance_variable_set(:@request, request)
          block ? block.call(owner.instance_variable_get(:@response)) : owner.instance_variable_get(:@response)
        end
        yield connection
      end
    end

    MESSAGES = [ { role: "system", content: "Tu aides." }, { role: "user", content: "Bonjour" } ].freeze
    BODY = { choices: [ { message: { content: "Salut" } } ], usage: { prompt_tokens: 12, completion_tokens: 3 } }.to_json

    def call(http, api_key: "sk-test", **args)
      OpenRouterLanguageModel.new(api_key:, http:).complete(messages: MESSAGES, model: "deepseek/deepseek-chat", max_tokens: 300, **args)
    end

    def capture_log
      io = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(io)
      yield
      io.string
    ensure
      Rails.logger = original
    end

    def assert_reason(reason, result)
      assert result.failure?
      assert_equal :unavailable, result.code
      assert_equal reason, result.errors[:reason]
    end

    test "success returns the text, the model, the tokens and a duration" do
      http = FakeHttp.new(response: Response.new("200", BODY))

      result = call(http)

      assert result.success?
      assert_equal "Salut", result.value[:text]
      assert_equal "deepseek/deepseek-chat", result.value[:model]
      assert_equal [ 12, 3 ], result.value.values_at(:input_tokens, :output_tokens)
      assert_kind_of Integer, result.value[:duration_ms]
    end

    test "the request is a bearer-authenticated JSON POST with the 5 s and 30 s timeouts" do
      http = FakeHttp.new(response: Response.new("200", BODY))

      call(http)

      assert_equal({ host: "openrouter.ai", port: 443, use_ssl: true, open_timeout: 5, read_timeout: 30 }, http.started_with)
      assert_equal "/api/v1/chat/completions", http.request.path
      assert_equal "Bearer sk-test", http.request["Authorization"]
      assert_equal "application/json", http.request["Content-Type"]
      sent = JSON.parse(http.request.body)
      assert_equal "deepseek/deepseek-chat", sent["model"]
      assert_equal 300, sent["max_tokens"]
      assert_equal MESSAGES.map(&:stringify_keys), sent["messages"]
      assert_equal OpenRouterLanguageModel::PROVIDER_PREFERENCES.deep_stringify_keys, sent["provider"]
      assert_nil sent["response_format"]
    end

    test "json asks for a JSON object" do
      http = FakeHttp.new(response: Response.new("200", BODY))

      call(http, json: true)

      assert_equal OpenRouterLanguageModel::JSON_RESPONSE_FORMAT.deep_stringify_keys, JSON.parse(http.request.body)["response_format"]
    end

    test "audio is attached to the last user message as base64 input_audio" do
      http = FakeHttp.new(response: Response.new("200", BODY))

      call(http, audio: { data: "OCTETS".b, format: "webm" })

      last = JSON.parse(http.request.body)["messages"].last
      parts = last["content"]
      assert_equal "text", parts.first["type"]
      assert_equal "Bonjour", parts.first["text"]
      assert_equal({ "data" => Base64.strict_encode64("OCTETS"), "format" => "webm" }, parts.last["input_audio"])
    end

    # Mesure du 2026-11-09 : une dictée réelle a dépassé 30 s (google/gemini-2.5-flash, échec à 31,7 s).
    test "a request with audio waits 90 s for the reply, a text request 30 s" do
      http = FakeHttp.new(response: Response.new("200", BODY))

      call(http, audio: { data: "OCTETS".b, format: "webm" })

      assert_equal 90, http.started_with[:read_timeout]
      assert_equal 5, http.started_with[:open_timeout]
    end

    test "without a key it is not configured and never calls out" do
      http = FakeHttp.new(response: Response.new("200", BODY))

      assert_reason :not_configured, call(http, api_key: nil)
      assert_nil http.started_with
    end

    test "429, 402, 500 and 503 are provider errors" do
      %w[429 402 500 503].each do |code|
        assert_reason :provider_error, call(FakeHttp.new(response: Response.new(code, "{}")))
      end
    end

    test "a connection or read timeout is a timeout" do
      assert_reason :timeout, call(FakeHttp.new(error: Net::ReadTimeout.new))
      assert_reason :timeout, call(FakeHttp.new(error: Net::OpenTimeout.new))
    end

    test "a timeout is logged with its class and the model, without the key or the messages" do
      logged = capture_log { call(FakeHttp.new(error: Net::ReadTimeout.new)) }

      assert_includes logged, "[crm.openrouter] timeout Net::ReadTimeout model=deepseek/deepseek-chat"
      assert_not_includes logged, "sk-test"
      assert_not_includes logged, "Bonjour"
    end

    test "a network error is a provider error" do
      assert_reason :provider_error, call(FakeHttp.new(error: SocketError.new("dns")))
      assert_reason :provider_error, call(FakeHttp.new(error: Errno::ECONNRESET.new))
    end

    test "a network error is logged with its class and the model, without the key or the messages" do
      logged = capture_log { call(FakeHttp.new(error: SocketError.new("dns sk-test Bonjour"))) }

      assert_includes logged, "[crm.openrouter] network SocketError model=deepseek/deepseek-chat"
      assert_not_includes logged, "sk-test"
      assert_not_includes logged, "Bonjour"
    end

    test "an unreadable body is an invalid response" do
      assert_reason :invalid_response, call(FakeHttp.new(response: Response.new("200", "<html>oops")))
    end

    test "a body without choices[0].message.content is an invalid response" do
      [ "{}", { choices: [] }.to_json, { choices: [ { message: {} } ] }.to_json, { choices: [ { message: { content: "  " } } ] }.to_json,
        "[]", "null" ].each do |body|
        assert_reason :invalid_response, call(FakeHttp.new(response: Response.new("200", body)))
      end
    end

    test "a response without usage counts zero tokens, and the provider's model name wins" do
      body = { model: "deepseek/deepseek-chat-v3", choices: [ { message: { content: "Salut" } } ] }.to_json

      result = call(FakeHttp.new(response: Response.new("200", body)))

      assert_equal [ "deepseek/deepseek-chat-v3", 0, 0 ], result.value.values_at(:model, :input_tokens, :output_tokens)
    end

    test "a non-2xx answer is logged with its status and model, never the body, the key or the messages" do
      logged = capture_log { call(FakeHttp.new(response: Response.new("401", "refusé sk-test Bonjour"))) }

      assert_includes logged, "[crm.openrouter] status=401 model=deepseek/deepseek-chat"
      %w[Bearer sk-test Bonjour refusé].each { assert_not_includes logged, it }
    end

    test "not_configured is logged as a warning" do
      assert_includes capture_log { call(FakeHttp.new(response: Response.new("200", BODY)), api_key: nil) }, "[crm.openrouter] not_configured"
    end

    test "Errno::ETIMEDOUT is a timeout" do
      assert_reason :timeout, call(FakeHttp.new(error: Errno::ETIMEDOUT.new))
    end

    test "a body of 2 MB is an invalid response, read in chunks under a 256 KB cap" do
      huge = { choices: [ { message: { content: "x" * (2 * 1024 * 1024) } } ] }.to_json

      assert_reason :invalid_response, call(FakeHttp.new(response: Response.new("200", huge)))
    end

    test "a body just under the cap is read" do
      body = { choices: [ { message: { content: "x" * 200_000 } } ] }.to_json

      assert call(FakeHttp.new(response: Response.new("200", body))).success?
    end

    test "a failure never carries the key" do
      result = call(FakeHttp.new(response: Response.new("500", "boom sk-test")))

      assert_not_includes result.inspect, "sk-test"
    end
  end
end
