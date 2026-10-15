# 🌐 DELIVERY · ProfileModalsHelper
# Rôle : forme des fenêtres du profil (nom, photo, code secret, numéro) selon le rôle du compte connecté
# UDR  : 0041, 0089 §3.4
module ProfileModalsHelper
  # Élève : feuille sous 700 px, au centre et 480 px au plus au-delà ; les autres rôles gardent la modale centrée étroite.
  def profile_modal_layout
    current_actor.student? ? { size: :form, placement: :phone_sheet } : { size: :sm }
  end
end
