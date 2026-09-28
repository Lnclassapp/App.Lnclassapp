# 🌐 DELIVERY · AuthenticatedController
# Rôle : parent des espaces connectés ; rend le shell, lui fournit la personne connectée, retient l'enseignant en attente
# ADR  : 0026, 0049, 0055, 0063 · UDR : 0006, 0050
class AuthenticatedController < ApplicationController
  # Une requête de frame (modale, re-rendu 422) garde le layout minimal de turbo-rails : le shell en ferait une page
  # complète, et Turbo y prendrait le frame vide du layout application. Sauf la page atteinte par Turbo juste après un
  # renouvellement de session depuis une modale (ADR-0049, ADR-0055) : le shell y porte la balise de rechargement,
  # et Turbo quitte le frame pour recharger le document.
  layout -> { turbo_frame_request? && !document_reload? ? "turbo_rails/frame" : "shell" }
  helper_method :shell_user
  # ADR-0063 : un enseignant sans école principale (compte en attente) n'accède qu'à l'écran d'attente.
  before_action :hold_pending_teacher

  private

  # Les conditions de ApplicationHelper#document_reload_tag.
  def document_reload? = flash[Authentication::RELOAD_FLASH] && request.headers["X-Turbo-Request-Id"].present?

  def hold_pending_teacher
    # L'acteur existe : la garde du second facteur (Authentication) s'arrête avant ce filtre sinon.
    redirect_to pending_account_path if current_actor.teacher? && current_actor.school_id.nil?
  end

  def shell_user
    @shell_user ||= NavigationHelper::ShellUser.new(
      **Queries::Identity::ShellUserQuery.new.call(user_id: current_session.user_id).to_h
    )
  end
end
