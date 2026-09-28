# 🧠 DOMAINE · UseCases::Classroom::ShowClassroomPlan
# Rôle : l'équipe lit le barème des classes tel que l'écran le montre : lignes du référentiel, nombres, totaux
# ADR  : 0028, 0058
module UseCases
  module Classroom
    class ShowClassroomPlan
      def initialize(classroom_plan:, taxonomy:, policy:)
        @classroom_plan = classroom_plan
        @taxonomy = taxonomy
        @policy = policy
      end

      # → Result(Entities::Classroom::DefaultClassroomPlan::Sheet) | :forbidden
      def call(actor:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        Shared::Result.success(Entities::Classroom::DefaultClassroomPlan.sheet(plan: @classroom_plan.plan, lookup: @taxonomy.lookup))
      end
    end
  end
end
