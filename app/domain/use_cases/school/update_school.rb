# 🧠 DOMAINE · UseCases::School::UpdateSchool
# Rôle : modifie nom, sigle, DRENA, type, statut et cycle d'un établissement ; ne crée ni ne supprime aucune classe
# ADR  : 0026, 0028, 0030, 0050 · UDR : 0036
module UseCases
  module School
    class UpdateSchool
      AUDITED = %w[drena_id name sigle school_type status cycle].freeze

      def initialize(schools:, drenas:, audit_log:, policy:, transaction:, clock:)
        @schools = schools
        @drenas = drenas
        @audit_log = audit_log
        @policy = policy
        @transaction = transaction
        @clock = clock
      end

      # dto : Dtos::School::SchoolInput. → Result(School) | :forbidden | :not_found | :invalid | :conflict (nom pris dans la DRENA)
      def call(actor:, public_id:, dto:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?

        current = @schools.find_by_public_id(public_id:)
        return Shared::Result.failure(:not_found) if current.nil?
        return Shared::Result.failure(:invalid, errors: dto.errors.to_hash) unless dto.valid?

        drena = @drenas.find_by_public_id(public_id: dto.drena_public_id)
        return Shared::Result.failure(:invalid, errors: { drena_public_id: [ :inclusion ] }) if drena.nil?

        @transaction.call do
          school = Entities::School::School.new(id: current.id, public_id: current.public_id, drena_id: drena.id, **dto.to_h)
          updated = @schools.update(school:)
          record(actor, current, updated.value) if updated.success?
          updated
        end
      end

      private

      def record(actor, before, after)
        changes = AUDITED.to_h { [ it, [ before.public_send(it), after.public_send(it) ] ] }.reject { |_, (from, to)| from == to }
        @audit_log.record(action: "school.changed", actor_id: actor.user_id, at: @clock.now, subject_type: "School",
                          subject_id: after.id, metadata: { change: "updated", public_id: after.public_id, changes: })
      end
    end
  end
end
