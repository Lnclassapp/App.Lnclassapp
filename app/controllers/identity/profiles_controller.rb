# 🌐 DELIVERY · Identity::ProfilesController
# Rôle : « Mon profil » de tout compte connecté ; aucun identifiant pris, toujours le compte de la session
# ADR  : 0055, 0063, 0094 · UDR : 0006, 0041, 0050
module Identity
  class ProfilesController < AuthenticatedController
    def show
      @profile = Queries::Identity::ProfileQuery.new.call(user_id: current_actor.user_id, current_school_id: current_actor.school_id)
      @referral = Queries::Identity::ReferralQuery.new.call(teacher_id: current_actor.user_id, school_id: current_actor.school_id) if current_actor.teacher?
    end
  end
end
