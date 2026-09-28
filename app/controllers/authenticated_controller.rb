# 🌐 DELIVERY · AuthenticatedController
# Rôle : parent des espaces connectés ; rend le shell et la personne connectée ; retient l'enseignant en attente et la direction sans établissement
# ADR  : 0026, 0049, 0055, 0060, 0063, 0066 · UDR : 0006, 0047, 0050, 0052
class AuthenticatedController < ApplicationController
  # Une requête de frame (modale, re-rendu 422) garde le layout minimal de turbo-rails : le shell en ferait une page
  # complète, et Turbo y prendrait le frame vide du layout application. Sauf la page atteinte par Turbo juste après un
  # renouvellement de session depuis une modale (ADR-0049, ADR-0055) : le shell y porte la balise de rechargement,
  # et Turbo quitte le frame pour recharger le document.
  layout -> { turbo_frame_request? && !document_reload? ? "turbo_rails/frame" : "shell" }
  helper_method :shell_user
  # ADR-0063 : un enseignant sans école principale (compte en attente) n'accède qu'à l'écran d'attente.
  before_action :hold_pending_teacher
  # ADR-0066 §4.2 : une direction sans établissement actif n'a que l'écran d'attente, son profil et la déconnexion.
  before_action :hold_detached_school_admin

  # Ouverts à la direction sans établissement : écran d'attente, « Mon profil » et ses modales, photo d'un compte.
  DETACHED_SCHOOL_ADMIN_PAGES = %r{\Aidentity/(pending_accounts|profile|account_photos)}

  private

  # Les conditions de ApplicationHelper#document_reload_tag.
  def document_reload? = flash[Authentication::RELOAD_FLASH] && request.headers["X-Turbo-Request-Id"].present?

  def hold_pending_teacher
    # L'acteur existe : la garde du second facteur (Authentication) s'arrête avant ce filtre sinon.
    redirect_to pending_account_path if current_actor.teacher? && current_actor.school_id.nil?
  end

  def hold_detached_school_admin
    return unless current_actor.school_admin? && current_actor.school_id.nil?

    redirect_to pending_account_path unless controller_path.match?(DETACHED_SCHOOL_ADMIN_PAGES)
  end

  # La photo remplace les initiales du menu du compte et de la barre latérale (ADR-0060).
  def shell_user
    @shell_user ||= Queries::Identity::ShellUserQuery.new.call(user_id: current_session.user_id).then do |row|
      NavigationHelper::ShellUser.new(name: row.name, role: row.role, detail: shell_detail(row),
                                      avatar_url: helpers.account_photo_src(row.public_id, row.photo_version))
    end
  end

  # La direction : « <Fonction> · <Établissement> » (UDR-0052 §3.1) ; les autres rôles : le détail de la query.
  def shell_detail(row)
    return row.detail if row.position.nil?

    "#{t("school_admin.shared.positions.#{row.position}")} · #{row.detail}"
  end
end
