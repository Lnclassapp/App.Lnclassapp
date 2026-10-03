# 🌐 UI · ThemeHelper — choix clair ou sombre retenu par l'interrupteur, sur cet appareil (cookie `theme`)
# Rôle : `data-theme` de <html> et meta color-scheme rendus par le serveur, pour un premier affichage juste
# UDR  : 0065 (amendement du 2026-10-03, interrupteur)
module ThemeHelper
  THEMES = %w[light dark].freeze
  COOKIE = "theme"

  # Le choix fait par l'interrupteur, ou nil : la page suit alors le réglage du téléphone. Toute autre valeur est ignorée.
  def theme_preference = cookies[COOKIE].presence_in(THEMES)

  def color_scheme_content = theme_preference || "light dark"
end
