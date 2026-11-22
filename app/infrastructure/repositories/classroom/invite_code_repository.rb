# 🔌 INFRA · Repositories::Classroom::InviteCodeRepository
# Rôle : code d'invitation opaque d'un élève (créé au premier besoin, stable ensuite) et résolution code → invitant
# ADR  : attribution-des-inscriptions-eleves
module Repositories
  module Classroom
    class InviteCodeRepository
      include Ports::Classroom::InviteCodeRepositoryPort

      ATTEMPTS = 3

      def code_for(student_id:)
        existing = Orm::StudentInviteCode.find_by(student_id:)&.code
        return ::Shared::Result.success(existing) if existing

        ATTEMPTS.times do
          code = Entities::Classroom::InviteCode.generate
          inserted = Orm::StudentInviteCode.insert({ student_id:, code: }) # ON CONFLICT DO NOTHING : élève ou code déjà pris
          return ::Shared::Result.success(code) if inserted.length.positive?

          # Une insertion vide : le code de l'élève existe (course) ; sinon le code tiré était pris.
          raced = Orm::StudentInviteCode.find_by(student_id:)&.code
          return ::Shared::Result.success(raced) if raced
        end
        Rails.logger.error("InviteCodeRepository: code unavailable for student_id=#{student_id}")
        ::Shared::Result.failure(:unavailable)
      end

      def inviter_for(code:)
        normalized = Entities::Classroom::InviteCode.normalize(code)
        return nil unless Entities::Classroom::InviteCode.valid?(normalized)

        Orm::StudentInviteCode.joins(:student).where(code: normalized, users: { anonymized_at: nil }).pick(:student_id)
      end
    end
  end
end
