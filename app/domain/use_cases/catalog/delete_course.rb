# 🧠 DOMAINE · UseCases::Catalog::DeleteCourse
# Rôle : l'équipe supprime définitivement une leçon (tout statut) et son contenu, si aucune activité d'élève ne s'y rattache
# ADR  : 0035, 0036, XXXX-suppression-d-une-lecon-sans-activite-eleve
module UseCases
  module Catalog
    class DeleteCourse
      def initialize(courses:, audit_log:, transaction:, policy:, clock:)
        @courses = courses
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Course supprimé, tel que lu avant) | :forbidden | :not_found | :conflict (base: student_activity)
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        course = @courses.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if course.nil?

        # La vérification suit le verrou de la leçon et de son contenu : une séance, une lecture ou un devoir écrit en même temps
        # attend la fin de la transaction, ou il est déjà là et la vérification le voit (ADR-XXXX §4.3).
        @transaction.call do
          activity = @courses.lock_for_deletion(id: course.id)
          next Shared::Result.failure(:not_found) if activity.nil?
          next Shared::Result.failure(:conflict, errors: { base: [ :student_activity ] }) if activity.any?

          deleted = @courses.delete(id: course.id)
          @audit_log.record(action: "content.deleted", actor_id: actor.user_id, subject_type: "Course", subject_id: course.id,
                            metadata: { slug:, name: course.name, status: course.status, deleted: }, at: @clock.now)
          Shared::Result.success(course)
        end
      end
    end
  end
end
