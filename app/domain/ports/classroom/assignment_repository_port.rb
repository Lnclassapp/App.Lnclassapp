# 🧠 DOMAINE · Ports::Classroom::AssignmentRepositoryPort
# Rôle : contrat des assignations d'une classe, et résolution polymorphe de la ressource assignée
# ADR  : 0035, 0048
module Ports
  module Classroom
    module AssignmentRepositoryPort
      # Ressource résolue : Entities::Classroom::Assignable, son statut et celui de ses parents.
      ResolvedAssignable = Data.define(:assignable, :status, :parents_published) do
        def readable? = status == "published" && parents_published
      end

      # → Entities::Classroom::Assignment | nil
      def active_for(classroom_id:, assignable:)
        raise NotImplementedError, "#{self.class} doit implémenter #active_for"
      end

      # → Entities::Classroom::Assignment | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Toujours une nouvelle ligne ; l'index partiel actif refuse un doublon.
      # → Result(Assignment) | failure(:conflict, errors: { base: [:already_assigned] })
      def create(assignment:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → true
      def archive(id:, archived_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archive"
      end

      # type ∈ Assignable::TYPES ; key = slug (Course, Essential) ou public_id (Exercise). → ResolvedAssignable | nil
      def resolve_assignable(type:, key:)
        raise NotImplementedError, "#{self.class} doit implémenter #resolve_assignable"
      end
    end
  end
end
