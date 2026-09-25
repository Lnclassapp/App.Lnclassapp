# 🌐 DELIVERY · ApplicationController
# Rôle : contrôleur parent de l'application ; signale un navigateur ancien sans le bloquer
# ADR  : 0051
class ApplicationController < ActionController::Base
  # ADR-0051 : Tailwind v4 floor, never blocking — an old browser gets the page and a banner.
  SUPPORTED_BROWSERS = { chrome: 111, safari: 16.4, firefox: 128, ie: false }.freeze
  allow_browser versions: SUPPORTED_BROWSERS, block: -> { @outdated_browser = true }
end
