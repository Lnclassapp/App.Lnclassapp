# 🧠 DOMAINE · Entities::Identity::Invitation
# Rôle : invitation d'un membre de l'équipe (ou de la direction en V2), jeton valable 72 h
# ADR  : 0038, 0044
module Entities
  module Identity
    Invitation = Data.define(:id, :kind, :contact, :team_role, :school_id, :invited_by_id,
                             :expires_at, :accepted_at, :accepted_user_id, :revoked_at) do
      def initialize(id:, kind:, contact:, expires_at:, team_role: nil, school_id: nil, invited_by_id: nil,
                     accepted_at: nil, accepted_user_id: nil, revoked_at: nil)
        raise ArgumentError, "type d'invitation inconnu : #{kind.inspect}" unless Invitation::KINDS.include?(kind)

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
    Invitation::TTL = 72.hours
    Invitation::TOKEN_LENGTH = 32
  end
end
