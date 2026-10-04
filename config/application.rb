require_relative "boot"

# rails/all, listed out. Action Text is back for course and essential content (owner's
# decision); Trix stays out of the common bundle (ADR-0051): the rich-text-editor
# controller loads it on demand.
require "rails"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "action_cable/engine"
require "action_mailbox/engine"
require "action_text/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AppLnclassapp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Côte d'Ivoire: UTC+0 all year, no daylight saving time.
    config.time_zone = "Africa/Abidjan"
    # config.eager_load_paths << Rails.root.join("extras")

    # Interface in French, code in English. One locale file per context and screen:
    # config/locales/<context>/<screen>.fr.yml (boucle-de-travail §6).
    config.i18n.default_locale = :fr
    config.i18n.available_locales = %i[fr en]
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.yml")]

    # ADR-0047 : files are served through the application (proxy mode): URLs stay on
    # our origin and the CSP never lists the bucket.
    config.active_storage.resolve_model_to_route = :rails_storage_proxy
    # ADR-0060 : no feature serves a file through Active Storage (photos: Identity::AccountPhotosController, under a
    # session and a policy) nor uploads directly (imports go through their form; the rich text editor refuses
    # attachments). Its routes are not drawn: a leaked signed id opens nothing, and no visitor creates a blob.
    config.active_storage.draw_routes = false
    # ADR-0060 : no image variant is ever generated (the browser crops the photo, the server serves it as is), and
    # neither image_processing nor libvips is in the image. Disabled explicitly, so that no boot asks for them.
    config.active_storage.variant_processor = :disabled

    # ADR-0052 : Mission Control Jobs is protected by the team area authentication.
    config.mission_control.jobs.base_controller_class = "Teams::BaseController"
    config.mission_control.jobs.http_basic_auth_enabled = false

    # UDR-0061 §3.4 : numéros et horaires du support (carte d'aide), publics, dans config/support.yml.
    config.x.support = config_for(:support)

    # ADR-0074 §4.6 : hôte des adresses partagées et indexées du blog (canonical, og:*, plan du site, robots.txt).
    # lnclass.com et www.lnclass.com servent tous deux l'application : la variable tranche, sans code. CANONICAL_HOST
    # doit figurer dans APP_HOSTS (docs/guide/configuration.md).
    config.x.canonical_host = ENV["CANONICAL_HOST"].presence || "lnclass.com"
  end
end
