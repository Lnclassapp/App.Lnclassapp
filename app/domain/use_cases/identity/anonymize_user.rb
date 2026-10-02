# 🧠 DOMAINE · UseCases::Identity::AnonymizeUser
# Rôle : l'équipe traite une demande de suppression : compte anonymisé en une transaction, résultats gardés, demande datée au journal
# ADR  : 0026, 0028, 0036 (§4), 0037, 0040, 0060
module UseCases
  module Identity
    class AnonymizeUser
      # ADR-0036 §4, conformes à l'ADR-0037.
      FIRST_NAME = "Compte".freeze
      LAST_NAME = "supprimé".freeze
      ALREADY_ANONYMIZED = { base: [ :already_anonymized ] }.freeze
      IN_FUTURE = { requested_on: [ :in_future ] }.freeze

      Anonymized = Data.define(:user, :requested_on)

      def initialize(users:, sessions:, second_factors:, pin_recoveries:, memberships:, photos:, audit_log:, transaction:,
                     policy:, clock:)
        @users = users
        @sessions = sessions
        @second_factors = second_factors
        @pin_recoveries = pin_recoveries
        @memberships = memberships
        @photos = photos
        @audit_log = audit_log
        @transaction = transaction
        @policy = policy
        @clock = clock
      end

      # dto : Dtos::Identity::DeletionRequestInput.
      # → success(Anonymized) | :forbidden | :not_found | :conflict (déjà anonymisé) | :invalid (requested_on)
      def call(actor:, target_public_id:, dto:)
        target = @users.find_by_public_id(public_id: target_public_id)
        return Shared::Result.failure(:not_found) if target.nil?

        allowed = @policy.call(actor:, target:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:conflict, errors: ALREADY_ANONYMIZED) if target.anonymized?

        now = @clock.now
        invalid = invalid_request(dto, now.to_date)
        return invalid if invalid

        @transaction.call { anonymize(actor, target, dto.requested_on, now) }
      end

      private

      def invalid_request(dto, today)
        return Shared::Result.failure(:invalid, errors: dto.errors.details.transform_values { it.pluck(:error) }) unless dto.valid?

        Shared::Result.failure(:invalid, errors: IN_FUTURE) if dto.requested_on > today
      end

      # Sessions, tentatives, badges, lacunes et adhésions restent : ce sont l'archive de l'établissement (ADR-0036 §4).
      # La photo est effacée dans la transaction : un échec plus loin laisse le compte intact, et la demande se rejoue.
      def anonymize(actor, target, requested_on, now)
        @photos.remove(user_id: target.id)
        @users.anonymize(user_id: target.id, first_name: FIRST_NAME, last_name: LAST_NAME, at: now)
        @sessions.destroy_all_for(user_id: target.id)
        @second_factors.reset(user_id: target.id)
        @pin_recoveries.destroy_all_for(user_id: target.id)
        @memberships.leave_all(student_id: target.id, at: now)
        @audit_log.record(action: "user.anonymized", actor_id: actor.user_id, at: now, subject_type: "User", subject_id: target.id,
                          metadata: { requested_on: requested_on.iso8601 })
        Shared::Result.success(Anonymized.new(user: target, requested_on:))
      end
    end
  end
end
