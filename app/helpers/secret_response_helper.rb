# 🌐 DELIVERY · SecretResponseHelper — exemption du cache Turbo pour les réponses marquées `secret_response`
# Rôle : meta turbo-cache-control dans le layout, ou flux qui l'ajoute au <head> de la page hôte d'une modale
# ADR  : 0031, 0049
module SecretResponseHelper
  # Layout : Turbo ne garde pas la page en cache, et ne la montre donc jamais en aperçu au retour.
  def secret_response_meta_tag
    turbo_exempts_page_from_cache_tag if secret_response?
  end

  # Flux Turbo : la page hôte reçoit le même meta ; quittée, elle n'est pas mise en cache avec le secret dans le DOM.
  def turbo_stream_secret_response
    turbo_stream.append_all("head", turbo_exempts_page_from_cache_tag)
  end
end
