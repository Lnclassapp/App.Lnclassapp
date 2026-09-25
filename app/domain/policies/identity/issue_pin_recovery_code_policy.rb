# 🧠 DOMAINE · Policies::Identity::IssuePinRecoveryCodePolicy
# Rôle : l'enseignant pour les élèves de ses classes actives, l'équipe pour tout autre compte
# ADR  : 0028, 0032
module Policies
  module Identity
    class IssuePinRecoveryCodePolicy
      # target : Entities::Identity::User ; teaches_target : élève d'une classe active qu'il enseigne
      def call(actor:, target:, teaches_target: false)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.teacher? && target.student? && teaches_target
        return Shared::Result.success if actor.team? && target.id != actor.user_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
