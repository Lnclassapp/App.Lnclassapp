# 🌐 DELIVERY · OfflineKeepable — marque « gardable hors ligne » une réponse HTML d'un compte connecté
# Rôle : `keep_offline only: %i[show]` pose `Lnclass-Offline: keep` ; le serveur décide seul. Une page HTML sans compte connecté porte `forget`
# ADR  : hors-connexion pages ouvertes et copies synchronisées (§4.1, menace P6) · posé sur aucune action au Lot 0
module OfflineKeepable
  extend ActiveSupport::Concern

  HEADER = "Lnclass-Offline".freeze

  included do
    # Filet de la déconnexion (menace P1) : toute page HTML vue sans compte connecté fait oublier la clé au programme d'arrière-plan.
    after_action :mark_offline_forget
  end

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

  def mark_offline_forget
    return if authenticated? || response.media_type != "text/html"

    response.set_header(HEADER, "forget")
  end
end
