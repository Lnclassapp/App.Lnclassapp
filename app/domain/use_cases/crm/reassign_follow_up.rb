# 🧠 DOMAINE · UseCases::Crm::ReassignFollowUp
# Rôle : confie une relance ouverte à un autre membre assignable ; l'admin, ou le responsable de l'école, seuls le peuvent
# ADR  : XXXX (contexte crm)
module UseCases
  module Crm
    class ReassignFollowUp
      # Règle partagée avec les écrans, qui n'offrent « Réattribuer » qu'à qui le peut.
      def self.allowed?(actor:, owner_id:)
        actor.team_role == "admin" || (!owner_id.nil? && owner_id == actor.user_id)
      end

      def initialize(follow_ups:, owners:, policy:, assignable:)
        @follow_ups = follow_ups
        @owners = owners
        @policy = policy
        @assignable = assignable
      end

      # → Result(FollowUp) | :forbidden | :not_found | :invalid (errors: assignee_id) ; une relance faite n'est plus à réattribuer
      def call(actor:, public_id:, assignee_id:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        follow_up = @follow_ups.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if follow_up.nil? || !follow_up.open?

        owner_id = @owners.owner_id(school_id: follow_up.school_id)
        return Shared::Result.failure(:forbidden) unless self.class.allowed?(actor:, owner_id:)
        return Shared::Result.failure(:invalid, errors: { assignee_id: [ :invalid ] }) unless @assignable.call.any? { it.user_id == assignee_id }

        @follow_ups.reassign(public_id:, assignee_id:)
      end
    end
  end
end
