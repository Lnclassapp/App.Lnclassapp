# 🧠 DOMAINE · UseCases::Communication::UpdatePushMotiveSetting
# Rôle : un admin de l'équipe coche ou décoche « Automatique » sur un motif ; seuls les trois motifs automatisables, jamais une relance
# ADR  : 0028 · XXXX envois de notifications (§4.1, §4.2) · UDR : XXXX écran notifications de l'équipe (§3.3)
module UseCases
  module Communication
    class UpdatePushMotiveSetting
      def initialize(settings:, policy:, clock:)
        @settings = settings
        @policy = policy
        @clock = clock
      end

      # Le dépôt écrit le réglage et sa ligne d'historique ensemble.
      # → Result(PushMotiveSetting) | :forbidden | :invalid (motif hors AUTOMATABLE, même forgé)
      def call(actor:, motive:, automatic:)
        allowed = @policy.call(actor:)
        return allowed if allowed.failure?
        return Shared::Result.failure(:invalid, errors: { motive: [ :not_automatable ] }) unless Entities::Communication::PushMotive.automatable?(motive)

        at = @clock.now
        @settings.update(motive:, automatic:, by: actor.user_id, at:)
        Shared::Result.success(Entities::Communication::PushMotiveSetting.new(motive:, automatic:, updated_by_id: actor.user_id, updated_at: at))
      end
    end
  end
end
