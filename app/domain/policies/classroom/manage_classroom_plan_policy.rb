# 🧠 DOMAINE · Policies::Classroom::ManageClassroomPlanPolicy
# Rôle : l'équipe lit et modifie le barème des classes générées, comme le reste du référentiel
# ADR  : 0028, 0058
module Policies
  module Classroom
    class ManageClassroomPlanPolicy
      def call(actor:)
        return Shared::Result.success if actor&.team?

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
