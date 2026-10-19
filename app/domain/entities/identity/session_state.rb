# 🧠 DOMAINE · Entities::Identity::SessionState
# Rôle : état d'une session serveur, trouvée par l'empreinte de son jeton ; fait des policies de session
# ADR  : 0031, 0050, 0094
module Entities
  module Identity
    # role : chaîne de users.role ; second_factor_confirmed : le compte a un second facteur confirmé ;
    # current_school_id : l'établissement courant d'une session d'enseignant, nil pour son principal (ADR-0094 §4.1).
    SessionState = Data.define(:id, :user_id, :role, :created_at, :last_seen_at, :second_factor_verified_at,
                               :second_factor_confirmed, :current_school_id) do
      def initialize(current_school_id: nil, **) = super

      def verified? = !second_factor_verified_at.nil?
      def team? = role.to_s == "team"
    end
  end
end
