# 🧠 DOMAINE · UseCases::Classroom::RegenerateClassroomLinks
# Rôle : régénère en masse les liens /c/<jeton> des classes actives d'une sélection (rapport classroom_links) ; jetons tirés par la base
# ADR  : 0085, 0096 · moteur : School::RegenerateInBulk
module UseCases
  module Classroom
    class RegenerateClassroomLinks < UseCases::School::RegenerateInBulk
      # classrooms : Ports::Classroom::ClassroomRepositoryPort ; les autres dépendances : celles du moteur.
      def initialize(classrooms:, **)
        super(**)
        @classrooms = classrooms
      end

      private

      def fetch(selection:, school_year:, created_before:, after_id:, limit:)
        @classrooms.link_regeneration_batch(selection:, school_year:, created_before:, after_id:, limit:)
      end

      def replace(candidates, at:, unchanged_since:)
        @classrooms.rotate_link_tokens(ids: candidates.map(&:id), at:, unchanged_since:)
      end

      # Sujet : l'établissement de la classe, comme l'archivage d'une classe ; jamais le jeton (ADR-0096 §4.4).
      def audit_entry(candidate)
        { subject_id: candidate.school_id, metadata: { change: "classroom_link_changed", classroom_public_id: candidate.public_id } }
      end
    end
  end
end
