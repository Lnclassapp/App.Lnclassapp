# 🧠 DOMAINE · Policies::Classroom::InviteClassmatesPolicy
# Rôle : seul un élève invite ses camarades dans sa classe
# ADR  : 0028, attribution-des-inscriptions-eleves
module Policies
  module Classroom
    class InviteClassmatesPolicy
      def call(actor:)
        return Shared::Result.success if actor&.student?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
