# 🧠 DOMAINE · Ports::School::TeacherDepartureRepositoryPort
# Rôle : contrat des retraits d'enseignants (teacher_school_departures) : inscrire, lire l'ouvert, fermer à la réintégration
# ADR  : 0071
module Ports
  module School
    module TeacherDepartureRepositoryPort
      # Un départ ouvert de plus ; l'index unique partiel en refuse un second pour le même couple (l'appelant l'a vérifié).
      # → Entities::School::TeacherDeparture
      def record(teacher_id:, school_id:, detached_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #record"
      end

      # → Entities::School::TeacherDeparture | nil
      def open_for(teacher_id:, school_id:)
        raise NotImplementedError, "#{self.class} doit implémenter #open_for"
      end

      # Pose reinstated_at et reinstated_by_id sur un départ encore ouvert ; un départ déjà clos ne change pas. → true
      def close(id:, reinstated_by_id:, at:)
        raise NotImplementedError, "#{self.class} doit implémenter #close"
      end
    end
  end
end
