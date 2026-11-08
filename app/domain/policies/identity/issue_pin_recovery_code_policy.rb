# 🧠 DOMAINE · Policies::Identity::IssuePinRecoveryCodePolicy
# Rôle : l'enseignant pour les élèves de ses classes actives ; l'équipe admin pour tout autre compte, le Terrain hors équipe
# ADR  : 0028, 0032, 0038
module Policies
  module Identity
    class IssuePinRecoveryCodePolicy
      # Matrice de l'ADR-0038 : admin et field émettent, content jamais. Le code d'un membre de l'équipe ouvre un compte
      # privilégié : seul l'admin l'émet, comme lui seul réinitialise le second facteur (B-001).
      TEAM_ISSUERS = %w[admin field].freeze

      # target : Entities::Identity::User ; teaches_target : élève d'une classe active qu'il enseigne
      def call(actor:, target:, teaches_target: false)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success if actor.teacher? && target.student? && teaches_target
        return Shared::Result.success if team_issues?(actor, target)

        Shared::Result.failure(:forbidden)
      end

      private

      def team_issues?(actor, target)
        return false unless actor.team? && TEAM_ISSUERS.include?(actor.team_role) && target.id != actor.user_id

        !target.team? || actor.team_role == "admin"
      end
    end
  end
end
