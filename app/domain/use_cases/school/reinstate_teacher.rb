# 🧠 DOMAINE · UseCases::School::ReinstateTeacher
# Rôle : la direction réintègre un enseignant qu'elle a retiré : rattaché de nouveau, sans classe ni devoir rendu ; départ clos
# ADR  : 0028, 0071 · UDR : 0056
module UseCases
  module School
    class ReinstateTeacher
      TEACHER = "teacher".freeze

      def initialize(users:, schools:, departures:, audit_log:, policy:, transaction:, clock:)
        @users = users
        @schools = schools
        @departures = departures
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # school_id : current_actor.school_id, jamais un paramètre. L'établissement est lu, puis autorisé (ADR-0071 §4.3).
      # → Result(Entities::Identity::User) | :forbidden | :not_found | :conflict (rattachement refusé par la base)
      def call(actor:, school_id:, teacher_public_id:)
        school = @schools.find_by_id(id: school_id)
        allowed = @policy.call(actor:, school:)
        return allowed if allowed.failure?

        teacher = @users.find_by_public_id(public_id: teacher_public_id)
        departure = teacher && reinstatable(teacher, school)
        return Shared::Result.failure(:not_found) if departure.nil?

        reinstate(actor, teacher, departure, @clock.now)
      end

      private

      # Un départ ouvert de cet établissement, et aucun établissement depuis : sinon, rien à réintégrer.
      def reinstatable(teacher, school)
        return if teacher.role != TEACHER || teacher.anonymized?
        return if @schools.primary_school_id_for(teacher_id: teacher.id)

        @departures.open_for(teacher_id: teacher.id, school_id: school.id)
      end

      # Le rattachement est la première écriture : refusé, rien n'a été écrit avant lui.
      def reinstate(actor, teacher, departure, now)
        @transaction.call do
          attached = @schools.attach_teacher(teacher_id: teacher.id, school_id: departure.school_id, primary: true, at: now)
          next attached if attached.failure?

          @departures.close(id: departure.id, reinstated_by_id: actor.user_id, at: now)
          @audit_log.record(action: "teacher.reinstated", actor_id: actor.user_id, at: now, subject_type: "User",
                            subject_id: teacher.id, metadata: { school_id: departure.school_id })
          Shared::Result.success(teacher)
        end
      end
    end
  end
end
