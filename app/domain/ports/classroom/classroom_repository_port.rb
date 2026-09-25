# 🧠 DOMAINE · Ports::Classroom::ClassroomRepositoryPort
# Rôle : contrat de persistance des classes, de leur code d'adhésion et de la génération par défaut
# ADR  : 0030, 0039, 0041
module Ports
  module Classroom
    module ClassroomRepositoryPort
      # Avec teacher_ids et active_students_count. → Entities::Classroom::Classroom | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Verrou (SELECT … FOR UPDATE), à appeler dans une transaction ; code déjà normalisé.
      # → Entities::Classroom::Classroom | nil
      def lock_by_join_code(join_code:)
        raise NotImplementedError, "#{self.class} doit implémenter #lock_by_join_code"
      end

      # Tire le code d'adhésion, retente une fois sur collision.
      # → Result(Classroom) | failure(:conflict, errors: { name: [:taken] })
      def create(classroom:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # rows : [{ school_id:, name:, level_id:, series_id: }] (DefaultClassroomPlan) ; codes tirés par
      # JoinCode.generate_unique contre les codes pris ; insert_all par 1 000. → Integer (classes créées)
      def insert_generated(rows:, school_year:, random:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #insert_generated"
      end

      # → Set[String]
      def school_year_names(school_id:, school_year:)
        raise NotImplementedError, "#{self.class} doit implémenter #school_year_names"
      end
    end
  end
end
