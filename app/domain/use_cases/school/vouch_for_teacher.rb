# 🧠 DOMAINE · UseCases::School::VouchForTeacher
# Rôle : un enseignant actif du même établissement se porte garant d'un collègue en attente : rattaché aussitôt, il devient son parrain
# ADR  : 0026, 0028, 0063 · UDR : 0050
module UseCases
  module School
    class VouchForTeacher
      def initialize(join_requests:, schools:, referrals:, audit_log:, policy:, transaction:, clock:)
        @join_requests = join_requests
        @schools = schools
        @referrals = referrals
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # Hors de son établissement, la demande n'existe pas pour l'acteur : :not_found, comme une demande inconnue (ADR-0028).
      # → Result(JoinRequest) | :not_found | :conflict (déjà traitée)
      def call(actor:, public_id:)
        request = @join_requests.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if request.nil?

        allowed = @policy.call(actor:, request:, school: @schools.find_by_id(id: request.school_id))
        return Shared::Result.failure(:not_found) if allowed.failure?
        return Shared::Result.failure(:conflict, errors: { base: [ :already_decided ] }) unless request.pending?

        now = @clock.now
        @transaction.call do
          approved = @join_requests.approve(id: request.id, decided_by_id: actor.user_id, via: "sponsor", at: now)
          next approved if approved.failure?

          sponsor(actor, request, now)
          Shared::Result.success(request)
        end
      end

      private

      # Un filleul déjà parrainé (par un lien) garde son parrain : le refus du parrainage n'annule pas la validation.
      def sponsor(actor, request, now)
        @referrals.record_referral(referrer_id: actor.user_id, referee_id: request.teacher_id, school_id: request.school_id,
                                   source: "sponsor", at: now)
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: now, subject_type: "School",
                          subject_id: request.school_id,
                          metadata: { change: "join_request_vouched", join_request: request.public_id, teacher_id: request.teacher_id })
      end
    end
  end
end
