# 🧠 DOMAINE · Policies::Classroom::ReadClassroomLessonPolicy
# Rôle : lire la leçon et une feuille vues depuis une classe : équipe et enseignant de la classe (et assignent), direction de son établissement (lecture seule)
# ADR  : lecture-de-la-classe-par-la-direction (suivi-classe-lecon), 0028, 0094
module Policies
  module Classroom
    class ReadClassroomLessonPolicy
      # can_assign : la vue n'affiche la barre d'assignation que s'il est vrai ; elle ne relit jamais le rôle.
      Access = Data.define(:can_assign)

      # classroom : répond à teacher_ids, student_ids et school_id. Une direction hors de l'établissement de la classe
      # ne doit pas la savoir existante : :not_found, pas :forbidden.
      def call(actor:, classroom:)
        if actor&.school_admin?
          return Shared::Result.success(Access.new(can_assign: false)) if actor.school_id && actor.school_id == classroom.school_id

          return Shared::Result.failure(:not_found)
        end

        read = ReadClassroomPolicy.new.call(actor:, classroom:)
        return read unless read.success?

        # L'élève lit la classe sans son détail : ces deux pages ne lui sont pas ouvertes.
        read.value.show_roster ? Shared::Result.success(Access.new(can_assign: true)) : Shared::Result.failure(:forbidden)
      end
    end
  end
end
