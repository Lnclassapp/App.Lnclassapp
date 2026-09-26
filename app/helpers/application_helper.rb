# 🌐 DELIVERY · ApplicationHelper
# Rôle : helpers de vue partagés par toute l'application ; rechargement du document après un changement de session
# ADR  : 0001, 0049
module ApplicationHelper
  # Une connexion ou une déconnexion change le nonce CSP (ADR-0049) : une visite Turbo, qui garderait la CSP de la page
  # précédente, recharge alors le document entier. Le flash est gardé pour la page rechargée, qui affiche le toast.
  # Un chargement hors Turbo reçoit déjà la bonne CSP : ni rechargement, ni flash gardé.
  def document_reload_tag
    return unless flash[Authentication::RELOAD_FLASH] && request.headers["X-Turbo-Request-Id"]

    flash.keep
    flash.discard(Authentication::RELOAD_FLASH)
    tag.meta(name: "turbo-visit-control", content: "reload")
  end
end
