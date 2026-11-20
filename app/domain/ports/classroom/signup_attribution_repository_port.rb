# 🧠 DOMAINE · Ports::Classroom::SignupAttributionRepositoryPort
# Rôle : contrat de la source d'inscription d'un élève (une ligne par élève, jamais réécrite)
# ADR  : attribution-des-inscriptions-eleves
module Ports
  module Classroom
    module SignupAttributionRepositoryPort
      # → Shared::Result : success même si une ligne existait déjà (elle reste inchangée)
      def record(student_id:, classroom_id:, source:, inviter_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end
    end
  end
end
