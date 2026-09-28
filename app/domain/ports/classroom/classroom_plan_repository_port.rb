# 🧠 DOMAINE · Ports::Classroom::ClassroomPlanRepositoryPort
# Rôle : contrat du barème des classes générées, une entrée par type d'établissement, niveau et série
# ADR  : 0058
module Ports
  module Classroom
    module ClassroomPlanRepositoryPort
      # Tout le barème, lu en une fois. → Entities::Classroom::ClassroomPlan
      def plan
        raise NotImplementedError, "#{self.class} doit implémenter #plan"
      end

      # entries : [ClassroomPlan::Entry] ; chacune remplace le nombre de même (type, niveau, série), ou s'ajoute. → true
      def save(entries:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #save"
      end
    end
  end
end
