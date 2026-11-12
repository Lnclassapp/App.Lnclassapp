# 🧠 DOMAINE · UseCases::Crm::ScheduleFollowUp
# Rôle : crée une relance ouverte pour une école, confiée à un membre assignable (admin ou field), avec une échéance et un motif (≤ 200)
# ADR  : XXXX (contexte crm)
module UseCases
  module Crm
    class ScheduleFollowUp
      def initialize(follow_ups:, policy:, assignable:, clock:)
        @follow_ups = follow_ups
        @policy = policy
        @assignable = assignable
        @clock = clock
      end

      # → Result(FollowUp) | :forbidden | :invalid (errors: reason, due_on, assignee_id)
      def call(actor:, school_id:, assignee_id:, due_on:, reason:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        reason = reason.to_s.squish
        errors = validate(reason:, due_on:, assignee_id:)
        return Shared::Result.failure(:invalid, errors:) if errors.any?

        @follow_ups.create(follow_up: Entities::Crm::FollowUp.new(
          public_id: nil, school_id:, assignee_id:, due_on:, reason:, status: "open", done_at: nil, done_by_id: nil,
          created_by_id: actor.user_id, interaction_id: nil
        ))
      end

      private

      def validate(reason:, due_on:, assignee_id:)
        errors = {}
        errors[:reason] = [ reason.empty? ? :blank : :too_long ] if reason.empty? || reason.length > Entities::Crm::FollowUp::REASON_MAX
        errors[:due_on] = [ :blank ] if due_on.nil?
        errors[:assignee_id] = [ :invalid ] unless @assignable.call.any? { it.user_id == assignee_id }
        errors
      end
    end
  end
end
