# 🌐 DELIVERY · AuthenticatedController
# Rôle : parent des espaces connectés ; rend le shell et lui fournit la personne connectée
# ADR  : 0026, 0049, 0055 · UDR : 0006
class AuthenticatedController < ApplicationController
  # Une requête de frame (modale, re-rendu 422) garde le layout minimal de turbo-rails : le shell en ferait une page
  # complète, et Turbo y prendrait le frame vide du layout application. Sauf la page atteinte par Turbo juste après un
  # renouvellement de session depuis une modale (ADR-0049, ADR-0055) : le shell y porte la balise de rechargement,
  # et Turbo quitte le frame pour recharger le document.
  layout -> { turbo_frame_request? && !document_reload? ? "turbo_rails/frame" : "shell" }
  helper_method :shell_user

  private

  # Les conditions de ApplicationHelper#document_reload_tag.
  def document_reload? = flash[Authentication::RELOAD_FLASH] && request.headers["X-Turbo-Request-Id"].present?

  def shell_user
    @shell_user ||= NavigationHelper::ShellUser.new(
      **Queries::Identity::ShellUserQuery.new.call(user_id: current_session.user_id).to_h
    )
  end
end
