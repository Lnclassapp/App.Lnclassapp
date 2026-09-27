# 🧠 DOMAINE · Ports::Assessment::BadgeRepositoryPort
# Rôle : contrat du meilleur badge d'un élève par exercice
# ADR  : 0033
module Ports
  module Assessment
    module BadgeRepositoryPort
      # → Entities::Assessment::Badge | nil
      def find(student_id:, exercise_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find"
      end

      # Sur (student_id, exercise_id). → Entities::Assessment::Badge
      def upsert(badge:)
        raise NotImplementedError, "#{self.class} doit implémenter #upsert"
      end
    end
  end
end
