# 🧠 DOMAINE · Ports::Classroom::AssignmentRepositoryPort
# Rôle : contrat des assignations d'une classe, et résolution polymorphe de la ressource assignée
# ADR  : 0035, 0048, 0071, 0072
module Ports
  module Classroom
    module AssignmentRepositoryPort
      # Ressource résolue : Entities::Classroom::Assignable, son statut et celui de ses parents.
      # course_level : { level_id:, series_id: } du cours (le contenu lui-même, ou celui de sa fiche) ; UDR-0013, amendement du 2026-10-01.
      ResolvedAssignable = Data.define(:assignable, :status, :parents_published, :course_level) do
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

      # Toujours une nouvelle ligne, échéance (due_on) comprise ; l'index partiel actif refuse un doublon.
      # → Result(Assignment) | failure(:conflict, errors: { base: [:already_assigned] })
      def create(assignment:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → true
      def archive(id:, archived_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archive"
      end

      # Retrait par la direction (ADR-0071) : archive, en une écriture, les assignations actives données par l'enseignant
      # (assigned_by_id) dans les classes de cet établissement ; les autres ne bougent pas. → Integer (devoirs archivés)
      def archive_all_by_teacher_in_school(teacher_id:, school_id:, archived_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archive_all_by_teacher_in_school"
      end

      # type = "Exercise", seul type assignable (ADR-0072 §4.1) ; key = public_id de l'exercice. → ResolvedAssignable | nil
      # Course et Essential (clé = slug) se résolvent encore tant que Assignable::TYPES les contient.
      def resolve_assignable(type:, key:)
        raise NotImplementedError, "#{self.class} doit implémenter #resolve_assignable"
      end
    end
  end
end
