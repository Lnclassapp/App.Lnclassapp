# 🔌 INFRA · Repositories::Identity::InviteLinkRepository
# Rôle : résout le jeton d'un lien /i/<jeton> : collègue de l'établissement (rattachement), parrainage (sans établissement),
#        puis direction, puis équipe ; un collègue anonymisé rend un lien invalide
# ADR  : 0063, 0083, 0094 (§11)
module Repositories
  module Identity
    class InviteLinkRepository
      include Ports::Identity::InviteLinkRepositoryPort

      ACTIVE = "active".freeze
      COLLEAGUE = "colleague".freeze
      SCHOOL_TOKENS = { "direction" => :direction_invite_token, "team" => :team_invite_token }.freeze

      # Un jeton commun à plusieurs tables (48 bits chacune) reste possible : le collègue passe d'abord (ADR-0083 §5).
      def resolve(token:)
        colleague(token) || sponsor(token) || SCHOOL_TOKENS.lazy.filter_map { |channel, column| school(token, channel, column) }.first
      end

      private

      # « Inviter un collègue de mon établissement » : le jeton d'une ligne teacher_schools. Le collègue parti de cet
      # établissement n'a plus de ligne : son lien est inconnu. Anonymisé (compte supprimé), il est invalide.
      def colleague(token)
        user_id, school_id, status, anonymized_at =
          Orm::TeacherSchool.joins(:teacher, :school).where(invite_token: token)
                            .pick(:teacher_id, :school_id, "schools.status", "users.anonymized_at")
        return if user_id.nil?
        return InviteLink.new(school_id: nil, school_active: false, channel: COLLEAGUE, referrer_id: user_id) if anonymized_at

        InviteLink.new(school_id:, school_active: status == ACTIVE, channel: COLLEAGUE, referrer_id: user_id)
      end

      # « Inviter un autre collègue » : le jeton du profil, sans établissement ; anonymisé, sans parrain, donc invalide.
      def sponsor(token)
        user_id, anonymized_at = Orm::TeacherProfile.joins(:user).where(referral_token: token).pick(:user_id, "users.anonymized_at")
        return if user_id.nil?

        InviteLink.new(school_id: nil, school_active: false, channel: COLLEAGUE, referrer_id: (user_id unless anonymized_at),
                       sponsor: true)
      end

      def school(token, channel, column)
        school_id, status = Orm::School.where(column => token).pick(:id, :status)
        school_id && InviteLink.new(school_id:, school_active: status == ACTIVE, channel:, referrer_id: nil)
      end
    end
  end
end
