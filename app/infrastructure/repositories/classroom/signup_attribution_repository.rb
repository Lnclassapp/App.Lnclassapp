# 🔌 INFRA · Repositories::Classroom::SignupAttributionRepository
# Rôle : écrit la source d'inscription d'un élève une seule fois ; une ligne existante reste inchangée
# ADR  : attribution-des-inscriptions-eleves
module Repositories
  module Classroom
    class SignupAttributionRepository
      include Ports::Classroom::SignupAttributionRepositoryPort

      def record(student_id:, classroom_id:, source:, inviter_id:, at:)
        Orm::SignupAttribution.insert({ student_id:, classroom_id:, source:, inviter_id:, created_at: at },
                                      unique_by: :student_id)
        ::Shared::Result.success
      end
    end
  end
end
