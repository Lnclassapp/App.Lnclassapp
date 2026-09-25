# 🧠 DOMAINE · Ports::Identity::TeacherProfileRepositoryPort
# Rôle : contrat du profil enseignant et de son onboarding
# ADR  : 0027, 0030
module Ports
  module Identity
    module TeacherProfileRepositoryPort
      # → Entities::Identity::TeacherProfile | nil
      def find_by_user_id(user_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_user_id"
      end

      # → true ; idempotent
      def complete_onboarding(user_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #complete_onboarding"
      end
    end
  end
end
