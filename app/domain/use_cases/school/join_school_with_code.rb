# 🧠 DOMAINE · UseCases::School::JoinSchoolWithCode
# Rôle : un enseignant sans établissement rejoint un établissement actif choisi dans sa DRENA, jamais celui qui l'a retiré
# ADR  : 0028, 0063, 0071, 0083 · UDR : 0056, 0079
module UseCases
  module School
    class JoinSchoolWithCode
      # join_requests : Ports::School::JoinRequestRepositoryPort ; seule une demande en attente va à la policy (ADR-0071 §4.5).
      # Le nom de la classe reste celui de la voie par code (ADR-0083 §4.3), pour limiter le diff.
      def initialize(schools:, drenas:, departures:, join_requests:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @drenas = drenas
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
        pending_request = (@join_requests.pending_for(teacher_id: actor.user_id) if actor&.teacher?)
        allowed = @policy.call(actor:, pending_request:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        school = @schools.find_by_public_id(public_id: dto.school_public_id)
        return Shared::Result.failure(:invalid, errors: { school_public_id: [ :inclusion ] }) unless joinable?(actor, school, dto)

        join(actor, school, @clock.now)
      end

      private

      # Établissement inconnu, inactif ou en brouillon, d'une autre DRENA, ou qui l'a retiré : la même erreur, rien n'est révélé.
      def joinable?(actor, school, dto)
        school&.active? && in_drena?(school, dto.drena_public_id) &&
          @departures.open_for(teacher_id: actor.user_id, school_id: school.id).nil?
      end

      def in_drena?(school, drena_public_id)
        @drenas.find_by_public_id(public_id: drena_public_id)&.id == school.drena_id
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
