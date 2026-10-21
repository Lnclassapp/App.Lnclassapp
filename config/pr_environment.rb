# ADR-XXXX : the application knows when it runs as a Railway PR environment, and closes it with a shared password.
# Plain Ruby, nothing else required: config/puma.rb loads this file before Rack and Rails, then config/application.rb.
module PrEnvironment
  # A PR environment is one whose PR_BASE_ENVIRONMENT is set and differs from the name of the environment it runs in
  # (Develop carries PR_BASE_ENVIRONMENT=Develop, its PRs inherit it under another RAILWAY_ENVIRONMENT_NAME).
  # Staging, production, development and test do not carry the variable: nothing here can fire there.
  def self.active?(env = ENV)
    base = env["PR_BASE_ENVIRONMENT"].to_s.strip
    name = env["RAILWAY_ENVIRONMENT_NAME"].to_s.strip
    !base.empty? && !name.empty? && name != base
  end

  # Rack middleware, first of the stack. Basic HTTP: the user name is free, the password is PR_ACCESS_PASSWORD.
  # Without that variable everything is refused (a forgotten variable closes the access), except /up, which Railway
  # probes for the health check.
  class Gate
    HEALTH_CHECK_PATH = "/up".freeze
    CHALLENGE = 'Basic realm="Lnclass PR"'.freeze

    def initialize(app, password: ENV["PR_ACCESS_PASSWORD"])
      @app = app
      @password = password.to_s
    end

    def call(env)
      return @app.call(env) if env["PATH_INFO"] == HEALTH_CHECK_PATH
      return @app.call(env) if authorized?(env["HTTP_AUTHORIZATION"])

      [ 401, { "content-type" => "text/plain; charset=utf-8", "www-authenticate" => CHALLENGE }, [ "Mot de passe requis.\n" ] ]
    end

    private

    def authorized?(header)
      return false if @password.strip.empty?

      scheme, encoded = header.to_s.split(" ", 2)
      return false unless scheme.to_s.casecmp?("basic") && encoded

      # Bytes, not characters: a malformed header must be refused, never raise.
      _user, given = encoded.unpack1("m").b.split(":".b, 2)
      !given.nil? && Rack::Utils.secure_compare(given, @password.b)
    end
  end
end
