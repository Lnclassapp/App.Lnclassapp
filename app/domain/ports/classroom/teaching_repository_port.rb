# 🧠 DOMAINE · Ports::Classroom::TeachingRepositoryPort
# Rôle : contrat des déclarations d'enseignement (teacher_classrooms)
# ADR  : 0030
module Ports
  module Classroom
    module TeachingRepositoryPort
      # Idempotent. → :created | :already
      def declare(teacher_id:, classroom_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #declare"
      end

      # Supprime la liaison, sans toucher aux assignations ni aux sessions. → true
      def withdraw(teacher_id:, classroom_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #withdraw"
      end

      # → [Integer]
      def classroom_ids_for(teacher_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #classroom_ids_for"
      end
    end
  end
end
