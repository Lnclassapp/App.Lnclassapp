# 🧠 DOMAINE · UseCases::School::LeaveSchool
# Rôle : l'enseignant quitte un de ses établissements : rattachement, classes et devoirs actifs de cet établissement, en une
#        transaction ; le plus ancien des restants devient principal ; aucun départ n'est noté, il peut revenir
# ADR  : 0028, 0036, 0071, 0094 · UDR : 0099 (§3.3)
module UseCases
  module School
    class LeaveSchool
      Left = Data.define(:school, :classrooms_count, :assignments_archived)
      LAST_SCHOOL = Shared::Result.failure(:forbidden, errors: { base: [ :last_school ] })

      # Un refus dans la transaction la traverse pour l'annuler, puis ressort en Result (comme DetachTeacher).
      class Aborted < StandardError
        attr_reader :result

        def initialize(result)
          @result = result
          super("départ annulé : #{result.code}")
        end
      end

      def initialize(schools:, teachings:, assignments:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @teachings = teachings
        @assignments = assignments
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # → success(Left) | :forbidden (dernier établissement : base last_school ; autre rôle) | :not_found (inconnu ou non
      #   rattaché)
      def call(actor:, school_public_id:)
        return Shared::Result.failure(:forbidden) unless actor&.teacher?

        school = @schools.find_by_public_id(public_id: school_public_id) if school_public_id
        school_ids = @schools.school_ids_for(teacher_id: actor.user_id)
        allowed = @policy.call(actor:, attached: !school.nil? && school_ids.include?(school.id), schools_count: school_ids.size)
        return allowed if allowed.failure?

        @transaction.call { leave(actor, school, @clock.now) }
      rescue Aborted => e
        e.result
      end

      private

      # Mêmes effets qu'un retrait par la direction dans cet établissement (ADR-0071), sans barrière de retour ; les
      # sessions, résultats et devoirs archivés restent (ADR-0036). Sous le verrou du compte, la règle est rejouée sur un
      # compte frais : deux départs simultanés (deux appareils), ou un départ et un retrait par la direction, se
      # sérialisent. La ligne déjà supprimée, ou plus aucun établissement après celui-ci, annulent tout.
      def leave(actor, school, now)
        teacher_id = actor.user_id
        @schools.lock_teacher(teacher_id:)
        school_ids = @schools.school_ids_for(teacher_id:)
        allowed = @policy.call(actor:, attached: school_ids.include?(school.id), schools_count: school_ids.size)
        raise Aborted, allowed if allowed.failure?
        raise Aborted, Shared::Result.failure(:not_found) if @schools.detach_teacher(teacher_id:, school_id: school.id).zero?
        left = Left.new(school:, classrooms_count: @teachings.withdraw_all_in_school(teacher_id:, school_id: school.id),
                        assignments_archived: @assignments.archive_all_by_teacher_in_school(teacher_id:, school_id: school.id,
                                                                                            archived_by_id: teacher_id, at: now))
        raise Aborted, LAST_SCHOOL if @schools.promote_primary(teacher_id:).nil?

        @audit_log.record(action: "teacher.left", actor_id: teacher_id, at: now, subject_type: "User", subject_id: teacher_id,
                          metadata: { school_id: school.id, classrooms_count: left.classrooms_count,
                                      assignments_archived: left.assignments_archived })
        Shared::Result.success(left)
      end
    end
  end
end
