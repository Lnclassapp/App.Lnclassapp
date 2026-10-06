# 🌐 DELIVERY · AuthenticatedController
# Rôle : parent des espaces connectés ; rend le shell (personne connectée : ShellLayout), retient l'enseignant en attente
# ADR  : 0026, 0049, 0055, 0060, 0063 · UDR : 0006, 0047, 0050
class AuthenticatedController < ApplicationController
  include ShellLayout

  # Une requête de frame (modale, re-rendu 422) garde le layout minimal de turbo-rails : le shell en ferait une page
  # complète, et Turbo y prendrait le frame vide du layout application. Sauf la page atteinte par Turbo juste après un
  # renouvellement de session depuis une modale (ADR-0049, ADR-0055) : le shell y porte la balise de rechargement,
  # et Turbo quitte le frame pour recharger le document.
  layout -> { turbo_frame_request? && !document_reload? ? "turbo_rails/frame" : "shell" }
  # ADR-0063 : un enseignant sans école principale (compte en attente) n'accède qu'à l'écran d'attente.
  before_action :hold_pending_teacher

  private

  # Les conditions de ApplicationHelper#document_reload_tag.
  def document_reload? = flash[Authentication::RELOAD_FLASH] && request.headers["X-Turbo-Request-Id"].present?

  def hold_pending_teacher
    # L'acteur existe : la garde du second facteur (Authentication) s'arrête avant ce filtre sinon.
    redirect_to pending_account_path if current_actor.teacher? && current_actor.school_id.nil?
  end
end
