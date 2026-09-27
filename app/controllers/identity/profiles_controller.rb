# 🌐 DELIVERY · Identity::ProfilesController
# Rôle : « Mon profil » de tout compte connecté ; aucun identifiant pris, toujours le compte de la session
# ADR  : 0055 · UDR : 0006, 0041
module Identity
  class ProfilesController < AuthenticatedController
    def show
      @profile = Queries::Identity::ProfileQuery.new.call(user_id: current_actor.user_id)
    end
  end
end
