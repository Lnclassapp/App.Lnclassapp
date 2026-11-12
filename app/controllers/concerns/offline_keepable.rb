# 🌐 DELIVERY · OfflineKeepable — marque « gardable hors ligne » une réponse HTML d'un compte connecté
# Rôle : `keep_offline only: %i[show]` pose `Lnclass-Offline: keep` ; le serveur décide seul, par une liste fermée d'actions
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.1, menace P6) · posé sur aucune action au Lot 0
module OfflineKeepable
  extend ActiveSupport::Concern

  HEADER = "Lnclass-Offline".freeze

  class_methods do
    def keep_offline(**options) = after_action(:mark_offline_keepable, **options)
  end

  private

  def mark_offline_keepable
    return unless authenticated? && response.status == 200 && response.media_type == "text/html"
    # Menace P6 : un écran secret ou une réponse no-store n'est jamais gardable, quel que soit le `only:` déclaré.
    return if (respond_to?(:secret_response?, true) && secret_response?) || response.headers["Cache-Control"].to_s.include?("no-store")

    response.set_header(HEADER, "keep")
  end
end
