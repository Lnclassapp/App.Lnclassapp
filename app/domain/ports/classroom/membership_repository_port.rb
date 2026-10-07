# 🧠 DOMAINE · Ports::Classroom::MembershipRepositoryPort
# Rôle : contrat des adhésions d'élèves, une seule classe principale active par élève ; voie d'arrivée et retrait
# ADR  : 0036, 0040, 0083
module Ports
  module Classroom
    module MembershipRepositoryPort
      # Adhésion principale active (left_at nul), avec le statut de sa classe. → Entities::Classroom::Membership | nil
      def primary_for(student_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #primary_for"
      end

      # via : Entities::Classroom::StudentArrivalChannel. Rouvre l'adhésion close d'un élève à cette classe (retrait levé,
      # joined_at = at) au lieu d'en créer une seconde.
      # → Result | failure(:conflict, errors: { base: [:already_member] }) ; index unique partiel
      def add_primary(classroom_id:, student_id:, via:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #add_primary"
      end

      # Pose left_at sur l'adhésion principale active (JoinAsStudent). → true
      def leave_primary(student_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #leave_primary"
      end

      # ADR-0083 §4.5 : clôt l'adhésion active de l'élève à cette classe et retient le retrait. Idempotent.
      # → true si une adhésion a été close, false si l'élève était déjà parti ou n'est jamais venu
      def remove(classroom_id:, student_id:, removed_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #remove"
      end

      # L'élève a été retiré de cette classe et n'y est pas revenu. → Boolean
      def removed_from?(classroom_id:, student_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #removed_from?"
      end

      # Pose left_at sur toutes les adhésions encore ouvertes de l'élève (anonymisation, ADR-0036 §4). → true
      def leave_all(student_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #leave_all"
      end
    end
  end
end
