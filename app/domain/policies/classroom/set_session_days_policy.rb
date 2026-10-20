# 🧠 DOMAINE · Policies::Classroom::SetSessionDaysPolicy
# Rôle : l'enseignant de la classe renseigne ses propres jours de séance, sur une classe active ; l'équipe n'en a pas
# ADR  : 0028, 0072, 0094
module Policies
  module Classroom
    class SetSessionDaysPolicy
      # classroom : répond à teacher_ids et active? ; les jours écrits sont toujours ceux de l'acteur.
      def call(actor:, classroom:)
        return ClassroomTeacher::OTHER_SCHOOL if actor && ClassroomTeacher.elsewhere?(actor, classroom)
        return Shared::Result.failure(:forbidden) unless actor && ClassroomTeacher.teaches?(actor, classroom)
        return Shared::Result.failure(:forbidden, errors: { base: [ :classroom_archived ] }) unless classroom.active?

        Shared::Result.success
      end
    end
  end
end
