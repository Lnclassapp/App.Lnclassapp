# 🌐 DELIVERY · ApplicationController
# Rôle : contrôleur parent ; authentifie par défaut, traduit les résultats, signale un navigateur ancien, ferme aux moteurs tout hôte hors production
# ADR  : 0026, 0031, 0050, 0051, 0074 (amendement du 2026-10-07)
class ApplicationController < ActionController::Base
  include Authentication
  include RendersResult
  include SecretResponse

  # ADR-0051 : Tailwind v4 floor, never blocking — an old browser gets the page and a banner.
  SUPPORTED_BROWSERS = { chrome: 111, safari: 16.4, firefox: 128, ie: false }.freeze
  allow_browser versions: SUPPORTED_BROWSERS, block: -> { @outdated_browser = true }

  # ADR-0074, amendement du 2026-10-07 : seule la production s'indexe ; ailleurs, chaque réponse le refuse. Posé en
  # premier, l'en-tête reste aussi sur une redirection décidée par un autre filtre (connexion exigée, par exemple).
  prepend_before_action do
    response.set_header("X-Robots-Tag", "noindex, nofollow") unless Rails.configuration.x.indexed_hosts.include?(request.host)
  end
end
