# 🌐 UI · OfflineHelper — la clé d'appareil du compte connecté, rendue dans la meta `lnclass-offline-key`
# Rôle : 16 caractères hexadécimaux, HMAC-SHA256 de l'identifiant avec une clé dérivée de secret_key_base ; opaque, stable, propre au compte
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.2, menace P2)
module OfflineHelper
  KEY_LENGTH = 16

  def offline_key_for(user_id)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("offline-key"), user_id.to_s).first(KEY_LENGTH)
  end

  # nil sans connexion (page publique) : la meta est absente.
  def offline_key_meta_tag
    user_id = current_actor&.user_id
    return if user_id.nil?

    tag.meta(name: "lnclass-offline-key", content: offline_key_for(user_id))
  end
end
