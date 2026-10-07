# 🧠 DOMAINE · Ports::Classroom::ClassroomRepositoryPort
# Rôle : contrat de persistance des classes, de leur code d'adhésion, du jeton de leur lien et de la génération par défaut
# ADR  : 0030, 0039, 0041, 0059, 0083
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

      # ADR-0083 §4.3 : même verrou, la classe choisie dans la cascade. → Entities::Classroom::Classroom | nil
      def lock_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #lock_by_public_id"
      end

      # ADR-0083 §4.1 : même verrou, la classe du lien /c/<jeton> ; nil pour un jeton inconnu ou remplacé.
      # → Entities::Classroom::Classroom | nil
      def lock_by_link_token(token:)
        raise NotImplementedError, "#{self.class} doit implémenter #lock_by_link_token"
      end

      # ADR-0083 §4.1 : tire un nouveau jeton, l'ancien est invalide aussitôt. → String (le nouveau jeton)
      def rotate_link_token(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #rotate_link_token"
      end

      # Tire le code d'adhésion, retente une fois sur collision.
      # → Result(Classroom) | failure(:conflict, errors: { name: [:taken] })
      def create(classroom:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # Codes d'adhésion déjà pris, pour tirer les nouveaux (JoinCode.generate_unique). → Set[String]
      def taken_join_codes
        raise NotImplementedError, "#{self.class} doit implémenter #taken_join_codes"
      end

      # rows : [{ public_id:, school_id:, school_year:, name:, level_id:, series_id:, join_code: }], public_id et
      # join_code déjà tirés par le domaine ; insert_all ; un code pris lève (le rejeu est l'affaire du moteur).
      # → Integer (classes créées)
      def insert_generated(rows:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #insert_generated"
      end

      # Noms déjà pris dans l'école pour l'année. → Set[String]
      def names_in(school_id:, school_year:)
        raise NotImplementedError, "#{self.class} doit implémenter #names_in"
      end

      # Noms des classes d'un couple niveau/série (series_id nil : sans série) dans l'école pour l'année. → [String]
      def names_in_level(school_id:, school_year:, level_id:, series_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #names_in_level"
      end

      # ADR-0059 : dans la transaction de l'appelant, verrouille la classe (comme l'adhésion par code), puis la supprime
      # si elle n'a jamais eu d'adhésion (même terminée), d'enseignant ni d'assignation (même archivée).
      # → Result | failure(:not_found) | failure(:conflict, errors: { base: [:has_students | :has_teachers | :has_assignments] })
      def delete_if_unused(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_if_unused"
      end
    end
  end
end
