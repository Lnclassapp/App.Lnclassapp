# 🌐 DELIVERY · AuthenticatedController
# Rôle : parent des espaces connectés ; rend le shell et lui fournit la personne connectée
# ADR  : 0026 · UDR : 0006
class AuthenticatedController < ApplicationController
  # Une requête de frame (modale, re-rendu 422) garde le layout minimal de turbo-rails : le shell en ferait une page
  # complète, et Turbo y prendrait le frame vide du layout application.
  layout -> { turbo_frame_request? ? "turbo_rails/frame" : "shell" }
  helper_method :shell_user

  private

  def shell_user
    @shell_user ||= NavigationHelper::ShellUser.new(
      **Queries::Identity::ShellUserQuery.new.call(user_id: current_session.user_id).to_h
    )
  end
end
