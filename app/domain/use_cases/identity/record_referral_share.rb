# 🧠 DOMAINE · UseCases::Identity::RecordReferralShare
# Rôle : enregistre un clic « Partager » (canal, date) d'un enseignant d'un établissement actif ; rien d'autre n'est gardé
# ADR  : 0028, 0049, 0063 · UDR : 0050
module UseCases
  module Identity
    class RecordReferralShare
      def initialize(referrals:, schools:, policy:, clock:)
        @referrals = referrals
        @schools = schools
        @policy = policy
        @clock = clock
      end

      # → success | :forbidden | :invalid (canal inconnu)
      def call(actor:, channel:)
        school = @schools.find_by_id(id: actor.school_id) if actor&.school_id
        allowed = @policy.call(actor:, school:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: { channel: [ :inclusion ] }) unless Entities::Identity::ShareChannel.valid?(channel)

        @referrals.record_share(user_id: actor.user_id, channel:, at: @clock.now)
      end
    end
  end
end
