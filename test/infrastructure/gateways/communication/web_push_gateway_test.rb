require "test_helper"

# ADR-0146 §4.2 et §4.3 : l'adaptateur Web Push (gem web-push, VAPID) ne lève jamais :
# 201 → delivered, 404/410/400/413 et clés illisibles → gone, 429/5xx/réseau → retry (401/403 : retry, journal error), un bug lève, clés absentes → not_configured. Aucun appel réseau : Net::HTTP est remplacé ;
# les clés sont une paire éphémère générée en mémoire.
module Gateways
  module Communication
    class WebPushGatewayTest < ActiveSupport::TestCase
      # Remplace Net::HTTP.new : enregistre la requête, répond ou lève ce qui est programmé.
      class FakeHttp
        attr_reader :sent
        attr_accessor :use_ssl, :ssl_timeout, :open_timeout, :read_timeout

        def initialize(response: nil, error: nil) = (@response = response; @error = error)

        def request(req)
          @sent = req
          raise @error if @error

          @response
        end
      end

      # Une réponse déjà lue : sans socket, Net::HTTP ne sait pas lire un corps absent.
      def reply(klass, code, message) = klass.new("1.1", code, message).tap { it.instance_variable_set(:@read, true) }

      setup do
        @vapid = WebPush.generate_key
        client = OpenSSL::PKey::EC.generate("prime256v1")
        @subscription = Entities::Communication::PushSubscription.new(
          id: 1, user_id: 1, endpoint: "https://push.example.test/send/abc",
          p256dh: WebPush.encode64(client.public_key.to_bn.to_s(2)), auth: WebPush.encode64(SecureRandom.random_bytes(16))
        )
        @message = Entities::Communication::PushMessage.new(title: "Lnclass", body: "Ta classe avance", url: "/", tag: "inactive")
      end

      def deliver(http, env: { "VAPID_PUBLIC_KEY" => @vapid.public_key, "VAPID_PRIVATE_KEY" => @vapid.private_key,
                              "VAPID_SUBJECT" => "mailto:contact@example.test" })
        with_env(env) do
          stub_method(Net::HTTP, :new, ->(*) { http }) { WebPushGateway.new.deliver(subscription: @subscription, message: @message) }
        end
      end

      # Comme capture_log, avec le niveau devant chaque ligne.
      def capture_leveled_log
        io = StringIO.new
        logger = ActiveSupport::Logger.new(io)
        logger.formatter = ->(severity, _, _, message) { "#{severity} #{message}\n" }
        Rails.logger.broadcast_to(logger)
        yield
        io.string
      ensure
        Rails.logger.stop_broadcasting_to(logger)
      end

      def with_env(values)
        previous = values.keys.index_with { ENV[it] }
        values.each { |key, value| ENV[key] = value }
        yield
      ensure
        previous.each { |key, value| ENV[key] = value }
      end

      test "201 : delivered, avec TTL 12 h, urgence normale, sujet = motif, signature VAPID et charge chiffrée" do
        http = FakeHttp.new(response: reply(Net::HTTPCreated, "201", "Created"))

        assert_equal :delivered, deliver(http)

        request = http.sent
        assert_equal "43200", request["Ttl"]
        assert_equal "normal", request["Urgency"]
        assert_equal "inactive", request["Topic"]
        assert_match(/\Avapid t=.+,k=.+\z/, request["Authorization"])
        assert_equal "aes128gcm", request["Content-Encoding"]
        assert_not_includes request.body, "Ta classe avance"
        assert http.use_ssl
        assert_equal 5, http.open_timeout
      end

      test "la charge chiffrée porte title, body, url et tag" do
        sent = nil
        encryption = ->(message, *) { sent = JSON.parse(message); "x" }
        http = FakeHttp.new(response: reply(Net::HTTPCreated, "201", "Created"))

        stub_method(WebPush::Encryption, :encrypt, encryption) { assert_equal :delivered, deliver(http) }

        assert_equal({ "title" => "Lnclass", "body" => "Ta classe avance", "url" => "/", "tag" => "inactive" }, sent)
      end

      test "404 et 410 : gone" do
        { reply(Net::HTTPNotFound, "404", "Not Found") => :gone, reply(Net::HTTPGone, "410", "Gone") => :gone }.each do |response, expected|
          assert_equal expected, deliver(FakeHttp.new(response:))
        end
      end

      test "429, 5xx ou réponse inattendue : retry, journal warn avec l'identifiant, le code et l'hôte" do
        [ reply(Net::HTTPTooManyRequests, "429", "Too Many"), reply(Net::HTTPInternalServerError, "500", "Boom"),
          reply(Net::HTTPServiceUnavailable, "503", "Down"), reply(Net::HTTPFound, "302", "Moved") ].each do |response|
          log = capture_leveled_log { assert_equal :retry, deliver(FakeHttp.new(response:)), response.code }

          assert_includes log, "WARN"
          assert_includes log, "subscription=1 code=#{response.code} host=push.example.test"
        end
      end

      test "401 et 403 : retry, mais journal error (clés VAPID suspectes), abonnement conservé" do
        [ reply(Net::HTTPUnauthorized, "401", "No"), reply(Net::HTTPForbidden, "403", "Forbidden") ].each do |response|
          log = capture_leveled_log { assert_equal :retry, deliver(FakeHttp.new(response:)), response.code }

          assert_match(/ERROR.*WebPushGateway\] retry: WebPush::Unauthorized subscription=1 code=#{response.code} host=push.example.test/, log)
        end
      end

      test "400 et 413 : gone" do
        [ reply(Net::HTTPBadRequest, "400", "Bad"), reply(Net::HTTPPayloadTooLarge, "413", "Big") ].each do |response|
          assert_equal :gone, deliver(FakeHttp.new(response:)), response.code
        end
      end

      test "400 UnauthorizedRegistration (FCM) : retry, journal error" do
        log = capture_leveled_log { assert_equal :retry, deliver(FakeHttp.new(response: reply(Net::HTTPBadRequest, "400", "UnauthorizedRegistration"))) }

        assert_match(/ERROR.*Unauthorized/, log)
      end

      test "le journal ne porte jamais l'adresse entière, ni la clé, ni la charge" do
        log = capture_log { deliver(FakeHttp.new(response: reply(Net::HTTPInternalServerError, "500", "Boom"))) }

        assert_not_includes log, "/send/abc"
        assert_not_includes log, @subscription.p256dh
        assert_not_includes log, "Ta classe avance"
      end

      test "délai dépassé ou erreur réseau : retry, sans lever, journal warn" do
        [ Net::ReadTimeout.new, Net::OpenTimeout.new, SocketError.new("dns"), Errno::ECONNRESET.new, OpenSSL::SSL::SSLError.new ].each do |error|
          log = capture_log { assert_equal :retry, deliver(FakeHttp.new(error:)), error.class.name }

          assert_includes log, "code=- host=push.example.test"
        end
      end

      test "une erreur de la gem sans réponse (configuration) : retry" do
        assert_equal :retry, deliver(FakeHttp.new(error: WebPush::ConfigurationError.new("vapid")))
      end

      test "des clés d'abonnement illisibles : gone" do
        @subscription = @subscription.with(p256dh: "pas-une-clé")

        assert_equal :gone, deliver(FakeHttp.new(response: reply(Net::HTTPCreated, "201", "Created")))
        assert_equal :gone, deliver(FakeHttp.new(error: OpenSSL::PKey::PKeyError.new("bad point")))
      end

      test "toute autre exception est un bug : elle lève" do
        assert_raises(NoMethodError) { deliver(FakeHttp.new(error: NoMethodError.new("bug"))) }
        assert_raises(RuntimeError) { deliver(FakeHttp.new(error: RuntimeError.new("bug"))) }
      end

      test "clés VAPID absentes ou vides : not_configured, sans appel réseau" do
        http = FakeHttp.new(response: reply(Net::HTTPCreated, "201", "Created"))
        [ {}, { "VAPID_PUBLIC_KEY" => nil, "VAPID_PRIVATE_KEY" => nil, "VAPID_SUBJECT" => nil },
          { "VAPID_PUBLIC_KEY" => "", "VAPID_PRIVATE_KEY" => @vapid.private_key, "VAPID_SUBJECT" => "mailto:a@b.test" },
          { "VAPID_PUBLIC_KEY" => @vapid.public_key, "VAPID_PRIVATE_KEY" => @vapid.private_key, "VAPID_SUBJECT" => nil } ].each do |env|
          cleared = { "VAPID_PUBLIC_KEY" => nil, "VAPID_PRIVATE_KEY" => nil, "VAPID_SUBJECT" => nil }.merge(env)
          assert_equal :not_configured, deliver(http, env: cleared)
        end
        assert_nil http.sent
      end
    end
  end
end
