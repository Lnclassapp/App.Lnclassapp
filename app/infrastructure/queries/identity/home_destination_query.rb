# 🔌 INFRA · Queries::Identity::HomeDestinationQuery
# Rôle : accueil d'un acteur connecté (école principale, puis l'entité) ; l'élève a-t-il une classe active
# ADR  : 0026, 0030, 0040, 0085
module Queries
  module Identity
    class HomeDestinationQuery
      # → Symbol ∈ Entities::Identity::HomeDestination::ALL
      def call(actor:)
        # UDR enseignant §3.13 : l'accueil porte « Ajoutez vos classes », la déclaration n'est plus une destination d'arrivée ;
        # l'onboarding enregistré ne sert plus qu'à la déclaration elle-même (TeachingSelectionQuery).
        Entities::Identity::HomeDestination.for(actor:, primary_school_id: primary_school_id(actor), onboarded: true)
      end

      # L'élève a une classe principale active (HomeDestination.enrolled?) ; false pour tout autre rôle.
      def enrolled?(actor:) = Entities::Identity::HomeDestination.enrolled?(primary_membership(actor))

      private

      def primary_membership(actor)
        return unless actor.student?

        row = Orm::ClassroomStudent.joins(:classroom).where(student_id: actor.user_id, primary: true, left_at: nil)
                                   .pick(:classroom_id, :joined_at, "classrooms.status")
        return if row.nil?

        classroom_id, joined_at, status = row
        Entities::Classroom::Membership.new(classroom_id:, student_id: actor.user_id, primary: true, joined_at:, left_at: nil,
                                            classroom_status: status)
      end

      def primary_school_id(actor)
        return unless actor.teacher?

        Orm::TeacherSchool.where(teacher_id: actor.user_id, primary: true).pick(:school_id)
      end
    end
  end
end
