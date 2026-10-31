# 🧠 DOMAINE · Ports::Classroom::AssignmentRepositoryPort
# Rôle : contrat des assignations d'une classe, et résolution polymorphe de la ressource assignée
# ADR  : 0035, 0048, 0071, 0072, sujets-de-devoir (ajout du 2026-10-30)
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

      # Résultat d'un envoi : created = Array<Assignment> créées, dans l'ordre d'entrée ;
      # skipped = Array<Assignable> écartées car déjà assignées (actives) à la classe.
      BatchCreation = Data.define(:created, :skipped)

      # Un envoi (ADR sujets-de-devoir, ajout du 2026-10-30). Contrat gelé par le Lot 0b, implémenté par le Lot E.
      # Entrée : assignments = Array<Entities::Classroom::Assignment>, de 1 à 10, d'une même classe, chacune avec le même
      #   batch_public_id et son échéance (due_on) ; ni id ni public_id n'existent encore (comme pour #create).
      # Écrit, en une seule transaction, une ligne par assignation reçue, dans l'ordre reçu. Un exercice déjà assigné à la
      #   classe (index partiel actif) est écarté et nommé, il n'annule pas l'envoi : les autres partent.
      # → Result(BatchCreation) ; created est vide si tous les exercices étaient déjà assignés.
      #   Aucune autre erreur n'est rendue : le choix des exercices et les droits se vérifient avant, dans le use case.
      def create_batch(assignments:)
        raise NotImplementedError, "#{self.class} doit implémenter #create_batch"
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
