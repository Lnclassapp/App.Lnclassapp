# 🧠 DOMAINE · UseCases::Crm::CompleteFollowUp
# Rôle : marque une relance « Faite » (qui, quand) ; une relance déjà faite est rendue telle quelle, sans écriture
# ADR  : XXXX (contexte crm)
module UseCases
  module Crm
    class CompleteFollowUp
      def initialize(follow_ups:, policy:, clock:)
        @follow_ups = follow_ups
        @policy = policy
        @clock = clock
      end

      # → Result(FollowUp) | :forbidden | :not_found
      def call(actor:, public_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        follow_up = @follow_ups.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if follow_up.nil?
        return Shared::Result.success(follow_up) unless follow_up.open?

        @follow_ups.complete(public_id:, by_id: actor.user_id, at: @clock.now)
      end
    end
  end
end
