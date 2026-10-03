# 🧠 DOMAINE · UseCases::Catalog::PublishCourse
# Rôle : l'équipe publie un brouillon ou republie un cours archivé ; jamais de retour au brouillon
# ADR  : 0026, 0028, 0035, 0050
module UseCases
  module Catalog
    class PublishCourse
      def initialize(courses:, audit_log:, transaction:, policy:, clock:)
        @courses = courses
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # → Result(Course relu, publié) | :forbidden | :not_found | :conflict (base: transition_not_allowed)
      def call(actor:, slug:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        course = @courses.find_by_slug(slug:)
        return Shared::Result.failure(:not_found) if course.nil?

        # Un cours n'a pas de parent : sa chaîne est publiée dès qu'il l'est.
        transition = Entities::Shared::ContentStatus.transition(from: course.status, to: "published", parent_published: true)
        return transition if transition.failure?

        @transaction.call do
          now = @clock.now
          @courses.transition(id: course.id, to: transition.value, at: now)
          @audit_log.record(action: "content.published", actor_id: actor.user_id, subject_type: "Course", subject_id: course.id,
                            metadata: { slug:, from: course.status }, at: now)
        end
        Shared::Result.success(@courses.find_by_slug(slug:))
      end
    end
  end
end
