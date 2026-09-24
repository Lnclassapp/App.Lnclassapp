# Debugbar is only bundled in development and test; enable it in development only.
if defined?(Debugbar)
  Debugbar.configure do |config|
    config.enabled = Rails.env.development?
  end
end
