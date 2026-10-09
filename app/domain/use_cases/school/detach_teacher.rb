# 🧠 DOMAINE · UseCases::School::DetachTeacher
# Rôle : la direction retire un enseignant de son établissement actif : rattachement, classes et devoirs actifs, en une transaction
# ADR  : 0026, 0028, 0071 · UDR : 0056
module UseCases
  module School
    class DetachTeacher
      Detached = Data.define(:teacher, :classrooms_count, :assignments_archived)
      TEACHER = "teacher".freeze

      # Un refus dans la transaction la traverse pour l'annuler, puis ressort en Result (comme Classroom::RegisterStudent).
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("retrait annulé : #{result.code}")
        end
      end

      def initialize(schools:, users:, teachings:, assignments:, departures:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @users = users
        @teachings = teachings
        @assignments = assignments
        @departures = departures
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # school_id : celui du compte de la direction, jamais un paramètre (ADR-0065).
      # → success(Detached) | :forbidden (policy) | :not_found (compte inconnu, non enseignant, anonymisé, ou non rattaché
      #   à cet établissement : un enseignant en attente n'a pas de rattachement)
      def call(actor:, school_id:, teacher_public_id:)
        allowed = @policy.call(actor:, school: school_id && @schools.find_by_id(id: school_id))
        return allowed if allowed.failure?

        teacher = @users.find_by_public_id(public_id: teacher_public_id)
        return Shared::Result.failure(:not_found) unless teacher&.role == TEACHER && !teacher.anonymized?

        @transaction.call { detach(actor, school_id, teacher, @clock.now) }
      rescue Aborted => e
        e.result
      end

      private

      # Le rattachement est supprimé d'abord : zéro ligne, c'est qu'il n'était pas de cet établissement (ou déjà retiré
      # dans un autre onglet) ; rien d'autre n'est écrit.
      def detach(actor, school_id, teacher, now)
        raise Aborted, Shared::Result.failure(:not_found) if @schools.detach_teacher(teacher_id: teacher.id, school_id:).zero?

        detached = Detached.new(
          teacher:,
          classrooms_count: @teachings.withdraw_all_in_school(teacher_id: teacher.id, school_id:),
          assignments_archived: @assignments.archive_all_by_teacher_in_school(teacher_id: teacher.id, school_id:,
                                                                              archived_by_id: actor.user_id, at: now)
        )
        @departures.record(teacher_id: teacher.id, school_id:, detached_by_id: actor.user_id, at: now)
        record(actor, school_id, detached, now)
        Shared::Result.success(detached)
      end

      def record(actor, school_id, detached, now)
        @audit_log.record(action: "teacher.detached", actor_id: actor.user_id, at: now, subject_type: "User",
                          subject_id: detached.teacher.id,
                          metadata: { school_id:, classrooms_count: detached.classrooms_count,
                                      assignments_archived: detached.assignments_archived })
      end
    end
  end
end
