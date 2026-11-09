# 🧠 DOMAINE · Policies::Identity::ResetSecondFactorPolicy
# Rôle : un membre admin de l'équipe réinitialise le second facteur d'un autre membre, jamais le sien (matrice ADR-0038)
# ADR  : 0028, 0031, 0038
module Policies
  module Identity
    class ResetSecondFactorPolicy
      # target : Entities::Identity::User, toujours exigé. content et field n'ont jamais le geste : réinitialiser le TOTP
      # d'un admin, avec un code de récupération du PIN, donne son compte (B-001).
      def call(actor:, target:)
        return Shared::Result.failure(:forbidden) unless actor&.team? && actor.team_role == "admin" && target
        return Shared::Result.success if target.team? && target.id != actor.user_id

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
