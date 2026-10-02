# 🧠 DOMAINE · Ports::Classroom::MembershipRepositoryPort
# Rôle : contrat des adhésions d'élèves, une seule classe principale active par élève
# ADR  : 0036, 0040
module Ports
  module Classroom
    module MembershipRepositoryPort
      # Adhésion principale active (left_at nul), avec le statut de sa classe. → Entities::Classroom::Membership | nil
      def primary_for(student_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #primary_for"
      end

      # → Result | failure(:conflict, errors: { base: [:already_member] }) ; index unique partiel
      def add_primary(classroom_id:, student_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #add_primary"
      end

      # Pose left_at sur l'adhésion principale active (JoinAsStudent). → true
      def leave_primary(student_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #leave_primary"
      end

      # Pose left_at sur toutes les adhésions encore ouvertes de l'élève (anonymisation, ADR-0036 §4). → true
      def leave_all(student_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #leave_all"
      end
    end
  end
end
