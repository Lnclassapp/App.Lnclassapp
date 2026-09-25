# 🧠 DOMAINE · Policies::Classroom::ManageClassroomPolicy
# Rôle : créer et gérer les classes : l'équipe en V1 (la direction de l'école en V2)
# ADR  : 0028, 0030
module Policies
  module Classroom
    class ManageClassroomPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
