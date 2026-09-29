# 🧠 DOMAINE · UseCases::School::ReviewJoinRequest
# Rôle : l'équipe valide (rattache) ou refuse un enseignant inscrit sans code, depuis la fiche ; chaque décision est auditée
# ADR  : 0026, 0028, 0063 · UDR : 0050
module UseCases
  module School
    class ReviewJoinRequest
      DECISIONS = %w[approve reject].freeze

      def initialize(join_requests:, audit_log:, policy:, transaction:, clock:)
        @join_requests = join_requests
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # decision : "approve" | "reject".
      # → Result(JoinRequest) | :forbidden | :invalid | :not_found | :conflict (déjà traitée)
      def call(actor:, public_id:, decision:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: { decision: [ :inclusion ] }) unless DECISIONS.include?(decision)

        request = @join_requests.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if request.nil?
        return Shared::Result.failure(:conflict, errors: { base: [ :already_decided ] }) unless request.pending?

        now = @clock.now
        @transaction.call do
          decided = decide(request, decision, actor, now)
          next decided if decided.failure?

          record(actor, request, decision == "approve" ? "join_request_approved" : "join_request_rejected", now)
          Shared::Result.success(request)
        end
      end

      private

      def decide(request, decision, actor, now)
        return @join_requests.reject(id: request.id, decided_by_id: actor.user_id, at: now) if decision == "reject"

        @join_requests.approve(id: request.id, decided_by_id: actor.user_id, via: "team", at: now)
      end

      def record(actor, request, change, now)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: now, subject_type: "School",
                          subject_id: request.school_id,
                          metadata: { change:, join_request: request.public_id, teacher_id: request.teacher_id })
      end
    end
  end
end
