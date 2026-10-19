# 🧠 DOMAINE · Entities::Identity::Invitation
# Rôle : invitation d'un membre de l'équipe (rôle) ou de la direction (école et fonction), jeton valable 72 h
# ADR  : 0038, 0044, 0065, 0092
module Entities
  module Identity
    Invitation = Data.define(:id, :kind, :contact, :team_role, :school_id, :position, :invited_by_id,
                             :expires_at, :accepted_at, :accepted_user_id, :revoked_at) do
      def initialize(id:, kind:, contact:, expires_at:, team_role: nil, school_id: nil, position: nil, invited_by_id: nil,
                     accepted_at: nil, accepted_user_id: nil, revoked_at: nil)
        raise ArgumentError, "type d'invitation inconnu : #{kind.inspect}" unless Invitation::KINDS.include?(kind)
        raise ArgumentError, "fonction inconnue : #{position.inspect}" unless position.nil? || Invitation::POSITIONS.include?(position)
        raise ArgumentError, "une invitation d'équipe exige un rôle" if kind == "team" && !User::TEAM_ROLES.include?(team_role)
        raise ArgumentError, "une invitation de direction exige une école" if kind == "school_staff" && school_id.nil?
        raise ArgumentError, "une invitation de direction exige une fonction" if kind == "school_staff" && position.nil?

        super
      end

      def self.generate_token = SecureRandom.base58(Invitation::TOKEN_LENGTH)

      def status(now:)
        return :accepted if accepted_at
        return :revoked if revoked_at
        return :expired if now >= expires_at

        :pending
      end
    end
    Invitation::KINDS = %w[team school_staff].freeze
    # Les quatre fonctions de direction (ADR-0092 §4.1), qui remplacent celles de l'ADR-0044.
    Invitation::POSITIONS = Entities::School::StaffPosition::ALL
    Invitation::TTL = 72.hours
    Invitation::TOKEN_LENGTH = 32
  end
end
