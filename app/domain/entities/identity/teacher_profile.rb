# 🧠 DOMAINE · Entities::Identity::TeacherProfile
# Rôle : profil 1-1 de l'enseignant, avec l'état persisté de son onboarding
# ADR  : 0027, 0030
module Entities
  module Identity
    TeacherProfile = Data.define(:user_id, :material_id, :onboarding_completed_at) do
      def onboarded? = !onboarding_completed_at.nil?
    end
  end
end
