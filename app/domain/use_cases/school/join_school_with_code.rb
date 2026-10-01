# 🧠 DOMAINE · UseCases::School::JoinSchoolWithCode
# Rôle : un enseignant sans établissement rejoint un établissement actif par son code, jamais celui qui l'a retiré
# ADR  : 0028, 0057, 0063, 0071 · UDR : 0056
module UseCases
  module School
    class JoinSchoolWithCode
      PENDING = "pending".freeze

      # join_requests : lecteur de la demande de l'enseignant, `status_for(teacher_id:)` → objet à `status` | nil, de tout
      # état (Queries::School::JoinRequestsQuery, ADR-0071 §4.5) ; seule une demande en attente va à la policy.
      def initialize(schools:, departures:, join_requests:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @departures = departures
        @join_requests = join_requests
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::School::SchoolJoinInput.
      # → Result(Entities::School::School) | :forbidden | :invalid | :conflict (rattachement refusé par la base)
      def call(actor:, dto:)
        allowed = @policy.call(actor:, pending_request: actor&.teacher? ? pending_request(actor) : nil)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        school = @schools.find_by_school_code(school_code: dto.school_code)
        return Shared::Result.failure(:invalid, errors: { school_code: [ :inclusion ] }) unless joinable?(actor, school)

        join(actor, school, @clock.now)
      end

      private

      def pending_request(actor)
        request = @join_requests.status_for(teacher_id: actor.user_id)
        request if request&.status == PENDING
      end

      # Code inconnu, établissement inactif ou en brouillon, établissement qui l'a retiré : la même erreur, rien n'est révélé.
      def joinable?(actor, school)
        school&.active? && @departures.open_for(teacher_id: actor.user_id, school_id: school.id).nil?
      end

      def join(actor, school, now)
        @transaction.call do
          attached = @schools.attach_teacher(teacher_id: actor.user_id, school_id: school.id, primary: true, at: now)
          next attached if attached.failure?

          @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: now, subject_type: "School",
                            subject_id: school.id, metadata: { change: "teacher_joined" })
          Shared::Result.success(school)
        end
      end
    end
  end
end
