# 🔌 INFRA · Repositories::Identity::InviteLinkRepository
# Rôle : résout le jeton d'un lien /i/<jeton> : parrainage d'un collègue (école principale, sauf anonymisé), puis direction, puis équipe
# ADR  : 0063, 0083
module Repositories
  module Identity
    class InviteLinkRepository
      include Ports::Identity::InviteLinkRepositoryPort

      ACTIVE = "active".freeze
      SCHOOL_TOKENS = { "direction" => :direction_invite_token, "team" => :team_invite_token }.freeze

      # Un jeton commun à plusieurs tables (48 bits chacune) reste possible : le collègue passe d'abord (ADR-0083 §5).
      def resolve(token:)
        colleague(token) || SCHOOL_TOKENS.lazy.filter_map { |channel, column| school(token, channel, column) }.first
      end

      private

      # Un collègue anonymisé (compte supprimé) peut garder son rattachement : son lien est invalide, comme sans école.
      def colleague(token)
        user_id, school_id, status, anonymized_at =
          Orm::TeacherProfile.joins(:user).joins(ReferralRepository::PRIMARY_SCHOOL).where(referral_token: token)
                             .pick(:user_id, "teacher_schools.school_id", "schools.status", "users.anonymized_at")
        return if user_id.nil?
        return InviteLink.new(school_id: nil, school_active: false, channel: "colleague", referrer_id: user_id) if anonymized_at

        InviteLink.new(school_id:, school_active: status == ACTIVE, channel: "colleague", referrer_id: user_id)
      end

      def school(token, channel, column)
        school_id, status = Orm::School.where(column => token).pick(:id, :status)
        school_id && InviteLink.new(school_id:, school_active: status == ACTIVE, channel:, referrer_id: nil)
      end
    end
  end
end
