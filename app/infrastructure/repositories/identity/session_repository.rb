# 🔌 INFRA · Repositories::Identity::SessionRepository
# Rôle : sessions serveur adressées par l'empreinte de leur jeton ; jamais le jeton en clair
# ADR  : 0031, 0050, 0055
module Repositories
  module Identity
    class SessionRepository
      include Ports::Identity::SessionRepositoryPort

      COLUMNS = %w[sessions.id sessions.user_id users.role sessions.created_at sessions.last_seen_at
                   sessions.second_factor_verified_at totp_credentials.confirmed_at].freeze

      def create(user_id:, token_digest:, ip:, user_agent:, at:)
        Orm::Session.create!(user_id:, token_digest:, ip_address: ip.to_s.first(45).presence,
                             user_agent: user_agent.to_s.first(255).presence, created_at: at, last_seen_at: at).id
      end

      def find_by_token_digest(token_digest:)
        row = Orm::Session.joins(:user)
                          .joins("LEFT JOIN totp_credentials ON totp_credentials.user_id = sessions.user_id")
                          .where(token_digest:).pick(*COLUMNS.map { Arel.sql(it) })
        return if row.nil?

        id, user_id, role, created_at, last_seen_at, verified_at, confirmed_at = row
        Entities::Identity::SessionState.new(id:, user_id:, role:, created_at:, last_seen_at:,
                                             second_factor_verified_at: verified_at, second_factor_confirmed: !confirmed_at.nil?)
      end

      def touch(id:, at:)
        Orm::Session.where(id:).update_all(last_seen_at: at)
        true
      end

      def mark_second_factor_verified(id:, at:)
        Orm::Session.where(id:).update_all(second_factor_verified_at: at, last_seen_at: at)
        true
      end

      def destroy(id:)
        Orm::Session.where(id:).delete_all
        true
      end

      def destroy_all_for(user_id:) = Orm::Session.where(user_id:).delete_all
      def destroy_all_except(user_id:, keep_id:) = Orm::Session.where(user_id:).where.not(id: keep_id).delete_all
    end
  end
end
