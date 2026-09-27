# 🧠 DOMAINE · Policies::Classroom::ReadClassroomPolicy
# Rôle : lire une classe : équipe, enseignant de la classe, élève dont c'est la classe active ; la liste pour les adultes
# ADR  : 0028, 0040
module Policies
  module Classroom
    class ReadClassroomPolicy
      Access = Data.define(:show_roster)

      # classroom : répond à teacher_ids et student_ids (adhésions actives)
      def call(actor:, classroom:)
        return Shared::Result.failure(:forbidden) if actor.nil?
        return Shared::Result.success(Access.new(show_roster: true)) if actor.team?
        return Shared::Result.success(Access.new(show_roster: true)) if actor.teacher? && classroom.teacher_ids.include?(actor.user_id)
        return Shared::Result.success(Access.new(show_roster: false)) if actor.student? && classroom.student_ids.include?(actor.user_id)

        Shared::Result.failure(:forbidden)
      end
    end
  end
end
