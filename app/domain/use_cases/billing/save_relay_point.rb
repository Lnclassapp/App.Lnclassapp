# 🧠 DOMAINE · UseCases::Billing::SaveRelayPoint
# Rôle : l'équipe crée ou modifie un point relais et remplace les écoles qu'il dessert ; le journal d'audit garde l'écriture
# ADR  : cartes-activation (contexte billing, §4.1 et §4.10)
module UseCases
  module Billing
    class SaveRelayPoint
      def initialize(relay_points:, audit_log:, transaction:, policy:, clock:)
        @relay_points = relay_points
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Billing::RelayPointInput ; public_id : nil à la création. → Result(Entities::Billing::RelayPoint)
      # | :forbidden | :invalid | :not_found (point relais inconnu)
      def call(actor:, dto:, public_id: nil)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        existing = public_id && @relay_points.find(public_id:)
        return Shared::Result.failure(:not_found) if public_id && existing.nil?

        @transaction.call { store(actor, dto, existing) }
      end

      private

      def store(actor, dto, existing)
        relay_point = Entities::Billing::RelayPoint.new(id: existing&.id, public_id: existing&.public_id, name: dto.name,
                                                        location: dto.location, phone: dto.phone, active: dto.active,
                                                        school_ids: dto.school_ids)
        saved = @relay_points.save(relay_point:, school_ids: dto.school_ids)
        return saved if saved.failure?

        @audit_log.record(action: "billing.relay_point_saved", actor_id: actor.user_id, at: @clock.now, subject_type: "RelayPoint",
                          subject_id: saved.value.id,
                          metadata: { change: existing ? "updated" : "created", name: saved.value.name, school_ids: saved.value.school_ids })
        saved
      end
    end
  end
end
