# 🧠 DOMAINE · Entities::Identity::SessionState
# Rôle : état d'une session serveur, trouvée par l'empreinte de son jeton ; fait des policies de session
# ADR  : 0031, 0050, 0066
module Entities
  module Identity
    # role : chaîne de users.role ; second_factor_confirmed : le compte a un second facteur confirmé
    SessionState = Data.define(:id, :user_id, :role, :created_at, :last_seen_at, :second_factor_verified_at,
                               :second_factor_confirmed) do
      def verified? = !second_factor_verified_at.nil?
      def team? = role.to_s == "team"
      # Second facteur exigé : l'équipe et la direction (ADR-0066 §4.2).
      def privileged? = SessionState::PRIVILEGED_ROLES.include?(role.to_s)
    end
    SessionState::PRIVILEGED_ROLES = %w[team school_admin].freeze
  end
end
