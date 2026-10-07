# 🧠 DOMAINE · Ports::School::SchoolRepositoryPort
# Rôle : contrat des établissements, de leur code d'établissement et du rattachement des enseignants
# ADR  : 0030, 0036, 0039, 0056, 0057, 0063, 0071, 0082 · UDR : 0078 · aucune recherche par code national (IE-21)
module Ports
  module School
    module SchoolRepositoryPort
      # Ligne insérée en masse, ou candidate à la génération : de quoi générer ses classes (DefaultClassroomPlan).
      Inserted = Data.define(:id, :public_id, :drena_id, :name, :school_type, :cycle)

      # → Entities::School::School | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Quel que soit son statut (ADR-0063). → Entities::School::School | nil
      def find_by_id(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_id"
      end

      # Quel que soit son statut : l'appelant décide (ADR-0057). → Entities::School::School | nil
      def find_by_school_code(school_code:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_school_code"
      end

      # Codes nationaux déjà pris, pour l'import. → Set[String]
      def taken_national_codes
        raise NotImplementedError, "#{self.class} doit implémenter #taken_national_codes"
      end

      # school : Entities::School::School sans id, avec son school_code tiré par le domaine.
      # → Result(School) | failure(:conflict, errors: { name: [:taken] })
      def create(school:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Ne touche jamais au code d'établissement.
      # → Result(School) | failure(:conflict, errors: { name: [:taken] } ou { national_code: [:taken] })
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

      # rows : [{ public_id:, drena_id:, name:, sigle:, school_type:, cycle:, status:, national_code:, school_code: }], public_id et
      # school_code tirés par le domaine ; insert_all avec RETURNING, created_at et updated_at posés par le repository.
      # → [Inserted]
      def insert_many(rows:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #insert_many"
      end

      # Codes d'établissement déjà pris, pour en tirer de nouveaux (ADR-0057). → Set[String]
      def taken_school_codes
        raise NotImplementedError, "#{self.class} doit implémenter #taken_school_codes"
      end

      # Remplace le code et date la régénération. → Result(School) | failure(:conflict) (code déjà pris)
      def replace_school_code(id:, school_code:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #replace_school_code"
      end

      # Candidats à la génération des classes manquantes (ADR-0056) : statut active ou draft, aucune classe (active ou
      # archivée) de school_year, id > after_id, par id croissant, `limit` au plus. → [Inserted]
      def without_classrooms(school_year:, after_id:, limit:)
        raise NotImplementedError, "#{self.class} doit implémenter #without_classrooms"
      end

      # Une seule école principale par enseignant (index partiel). → Result | failure(:conflict)
      def attach_teacher(teacher_id:, school_id:, primary:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #attach_teacher"
      end

      # → Integer | nil
      def primary_school_id_for(teacher_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #primary_school_id_for"
      end

      # Retrait par la direction (ADR-0071) : supprime le rattachement à cet établissement, jamais à un autre.
      # → Integer (lignes teacher_schools supprimées)
      def detach_teacher(teacher_id:, school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #detach_teacher"
      end
    end
  end
end
