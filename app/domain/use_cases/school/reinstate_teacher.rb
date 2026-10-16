# 🧠 DOMAINE · UseCases::School::ReinstateTeacher
# Rôle : la direction réintègre un enseignant qu'elle a retiré : rattaché de nouveau (en plus de ses autres établissements, dans
#        le plafond), sans classe ni devoir rendu ; départ clos
# ADR  : 0028, 0071, 0094, 0103 · UDR : 0056, 0100 (§3.3)
module UseCases
  module School
    class ReinstateTeacher
      TEACHER = "teacher".freeze

      # teacher_materials : Ports::Identity::TeacherMaterialRepositoryPort ; il retrouve ses matières de cet établissement
      # (ADR-0103 §4.4).
      def initialize(users:, schools:, departures:, audit_log:, policy:, transaction:, clock:, teacher_materials:)
        @users = users
        @teacher_materials = teacher_materials
        @schools = schools
        @departures = departures
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # school_id : current_actor.school_id, jamais un paramètre. L'établissement est lu, puis autorisé (ADR-0071 §4.3).
      # → Result(Entities::Identity::User) | :forbidden | :not_found | :conflict (base schools_limit : plafond atteint ;
      #   already_attached), rien n'est écrit
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

      # Un départ ouvert de cet établissement, qu'il ait rejoint un autre établissement depuis ou non (ADR-0094 §4.4).
      def reinstatable(teacher, school)
        return if teacher.role != TEACHER || teacher.anonymized?

        @departures.open_for(teacher_id: teacher.id, school_id: school.id)
      end

      # Le rattachement est la première écriture, sous le verrou du compte et le plafond : refusé, rien n'a été écrit avant
      # lui. Principal s'il n'a aucun autre établissement, secondaire sinon.
      def reinstate(actor, teacher, departure, now)
        @transaction.call do
          primary = @schools.school_ids_for(teacher_id: teacher.id).empty?
          attached = @schools.attach_teacher_within_cap(teacher_id: teacher.id, school_id: departure.school_id, primary:,
                                                        cap: Entities::School::TeacherSchools::MAX, at: now)
          next attached if attached.failure?

          @teacher_materials.inherit(teacher_id: teacher.id, school_id: departure.school_id, from_school_id: nil, at: now)
          @departures.close(id: departure.id, reinstated_by_id: actor.user_id, at: now)
          @audit_log.record(action: "teacher.reinstated", actor_id: actor.user_id, at: now, subject_type: "User",
                            subject_id: teacher.id, metadata: { school_id: departure.school_id })
          Shared::Result.success(teacher)
        end
      end
    end
  end
end
