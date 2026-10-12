# 🧠 DOMAINE · Ports::Classroom::ClassroomRepositoryPort
# Rôle : contrat de persistance des classes, du jeton de leur lien et de la génération par défaut
# ADR  : 0030, 0039, 0041, 0059, 0085, 0088
module Ports
  module Classroom
    module ClassroomRepositoryPort
      # Avec teacher_ids et active_students_count. → Entities::Classroom::Classroom | nil
      def find_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #find_by_public_id"
      end

      # Verrou (SELECT … FOR UPDATE), à appeler dans une transaction ; ADR-0085 §4.3 : la classe choisie dans la cascade.
      # → Entities::Classroom::Classroom | nil
      def lock_by_public_id(public_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #lock_by_public_id"
      end

      # ADR-0085 §4.1 : même verrou, la classe du lien /c/<jeton> ; nil pour un jeton inconnu ou remplacé.
      # → Entities::Classroom::Classroom | nil
      def lock_by_link_token(token:)
        raise NotImplementedError, "#{self.class} doit implémenter #lock_by_link_token"
      end

      # ADR-0085 §4.1 : tire un nouveau jeton, l'ancien est invalide aussitôt. → String (le nouveau jeton)
      def rotate_link_token(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #rotate_link_token"
      end

      # → Result(Classroom) | failure(:conflict, errors: { name: [:taken] })
      def create(classroom:)
        raise NotImplementedError, "#{self.class} doit implémenter #create"
      end

      # rows : [{ public_id:, school_id:, school_year:, name:, level_id:, series_id: }], public_id déjà tiré par le domaine ;
      # insert_all ; un nom pris lève (le rejeu est l'affaire du moteur).
      # → Integer (classes créées)
      def insert_generated(rows:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #insert_generated"
      end

      # Noms déjà pris dans l'école pour l'année. → Set[String]
      def names_in(school_id:, school_year:)
        raise NotImplementedError, "#{self.class} doit implémenter #names_in"
      end

      # Noms des classes ACTIVES d'un couple niveau/série (series_id nil : sans série) dans l'école pour l'année : l'archivée n'est
      # jamais la « dernière » que retire « − » (ADR-0088). Pour numéroter une classe nouvelle, names_in prend toutes les classes. → [String]
      def names_in_level(school_id:, school_year:, level_id:, series_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #names_in_level"
      end

      # ADR-0059 : dans la transaction de l'appelant, verrouille la classe (comme l'adhésion d'un élève), puis la supprime
      # si elle n'a jamais eu d'adhésion (même terminée), d'enseignant ni d'assignation (même archivée).
      # → Result | failure(:not_found) | failure(:conflict, errors: { base: [:has_students | :has_teachers | :has_assignments] })
      def delete_if_unused(id:)
        raise NotImplementedError, "#{self.class} doit implémenter #delete_if_unused"
      end

      # ADR-0088 : dans la transaction de l'appelant, passe la classe en « archived » avec sa date ; adhésions, enseignants et
      # assignations ne sont pas touchés. → Result(Classroom) | failure(:not_found)
      #   | failure(:conflict, errors: { base: [:already_archived] })
      def archive(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archive"
      end

      # ADR-0088 : l'inverse, la date d'archivage est effacée. → Result(Classroom) | failure(:not_found)
      #   | failure(:conflict, errors: { base: [:not_archived] })
      def restore(id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #restore"
      end

      # ADR-0088 : archive les classes ACTIVES d'un niveau (toutes séries) d'un établissement pour l'année. → Integer (classes archivées)
      def archive_level(school_id:, school_year:, level_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #archive_level"
      end
    end
  end
end
