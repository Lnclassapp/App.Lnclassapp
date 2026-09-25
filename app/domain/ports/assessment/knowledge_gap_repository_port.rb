# 🧠 DOMAINE · Ports::Assessment::KnowledgeGapRepositoryPort
# Rôle : contrat des lacunes, une seule en attente par élève et par fiche
# ADR  : 0043
module Ports
  module Assessment
    module KnowledgeGapRepositoryPort
      # → Entities::Assessment::KnowledgeGap | nil
      def pending_for(student_id:, essential_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #pending_for"
      end

      # → KnowledgeGap | nil
      def find(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # Une création qui heurte l'index partiel renvoie la lacune en attente. → KnowledgeGap
      def open(student_id:, essential_id:, source_session_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #open"
      end

      # failed_sessions_count + 1. → true
      def increment(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #increment"
      end

      # status ∈ remediated, self_corrected. → true
      def resolve(id:, status:, session_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #resolve"
      end
    end
  end
end
