# 🧠 DOMAINE · UseCases::Catalog::ArchiveCourse
# Rôle : l'équipe archive un cours publié ; ses fiches, exercices et assignations restent intacts
# ADR  : 0026, 0028, 0035, 0036, 0050
module UseCases
  module Catalog
    class ArchiveCourse
      def initialize(courses:, audit_log:, transaction:, policy:, clock:)
        @courses = courses
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Course relu, archivé) | :forbidden | :not_found | :conflict (base: transition_not_allowed)
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        course = @courses.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if course.nil?

        transition = Entities::Catalog::ContentStatus.transition(from: course.status, to: "archived", parent_published: true)
        return transition if transition.failure?

        # Seul le statut du cours change : la visibilité de sa descendance suit la chaîne des parents (ADR-0035).
        @transaction.call do
          now = @clock.now
          @courses.transition(id: course.id, to: transition.value, at: now)
          @audit_log.record(action: "content.archived", actor_id: actor.user_id, subject_type: "Course", subject_id: course.id,
                            metadata: { slug:, from: course.status }, at: now)
        end
        Shared::Result.success(@courses.find_by_slug(slug:))
      end
    end
  end
end
