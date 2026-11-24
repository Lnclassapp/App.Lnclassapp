# ADR-0140 (amendment of 2026-11-17): the Active Storage service of the environment, read from ACTIVE_STORAGE_SERVICE.
# Staging and Develop on the VPS keep their files on a Docker volume ("local"); everywhere else the bucket ("railway").
# Plain Ruby, nothing else required: loaded by config/environments/production.rb.
module StorageService
  ALLOWED = %w[railway local].freeze

  # The production container has no volume for files: "local" there would lose every new file at the next deploy
  # (F-25), and the deployer re-sends the VPS .env, so a wrong value would last. It stops the boot instead.
  def self.for(env = ENV)
    name = env["ACTIVE_STORAGE_SERVICE"].to_s.strip
    name = "railway" if name.empty?
    raise ArgumentError, "ACTIVE_STORAGE_SERVICE=#{name}: only #{ALLOWED.join(' or ')}" unless ALLOWED.include?(name)
    if name == "local" && env["RAILWAY_ENVIRONMENT_NAME"].to_s.strip.casecmp?("production")
      raise ArgumentError, "ACTIVE_STORAGE_SERVICE=local refused in production: its container keeps no file (F-25)"
    end

    name.to_sym
  end
end
