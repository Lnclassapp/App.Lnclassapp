# 🧠 DOMAINE · Ports::School::SchoolRepositoryPort
# Rôle : contrat des établissements et du rattachement des enseignants
# ADR  : 0030, 0036, 0039
module Ports
  module School
    module SchoolRepositoryPort
      # Ligne insérée en masse : de quoi générer ses classes (DefaultClassroomPlan).
      Inserted = Data.define(:id, :public_id, :drena_id, :name, :school_type, :cycle)

      # → Entities::School::School | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # school : Entities::School::School sans id. → Result(School) | failure(:conflict, errors: { name: [:taken] })
      def create(school:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # → Result(School) | failure(:conflict, errors: { name: [:taken] })
      def update(school:)
        raise NotImplementedError, "#{self.class} doit implémenter #update"
      end

      # Supprime aussi ses classes si aucune n'a d'élève, d'enseignant ni d'assignation.
      # → Result | failure(:conflict, errors: { base: [:referenced] })
      def delete_if_unreferenced(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_if_unreferenced"
      end

      # Clés de doublon de l'import. → Set[[drena_id, Entities::Shared::NaturalKey.normalize(name)]]
      def existing_keys(drena_ids:)
        raise NotImplementedError, "#{self.class} doit implémenter #existing_keys"
      end

      # rows : [{ public_id:, drena_id:, name:, sigle:, school_type:, cycle:, status: }], public_id tiré par le
      # domaine ; insert_all avec RETURNING, created_at et updated_at posés par le repository.
      # → [Inserted]
      def insert_many(rows:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #insert_many"
      end

      # Une seule école principale par enseignant (index partiel). → Result | failure(:conflict)
      def attach_teacher(teacher_id:, school_id:, primary:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach_teacher"
      end

      # → Integer | nil
      def primary_school_id_for(teacher_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #primary_school_id_for"
      end
    end
  end
end
