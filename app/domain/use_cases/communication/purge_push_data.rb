# 🧠 DOMAINE · UseCases::Communication::PurgePushData
# Rôle : supprime les abonnements sans envoi réussi depuis 60 jours, les envois, les validations et l'historique des réglages de plus de 90 jours
# ADR  : 0146 (§4.1) · XXXX envois de notifications (§4.1, §6) · sans acteur ni policy (job) : exemption de test/architecture/use_case_policies_test.rb
module UseCases
  module Communication
    class PurgePushData
      SUBSCRIPTION_TTL = 60.days
      DELIVERY_TTL = 90.days

      # approvals : PushApprovalRepositoryPort ; settings : PushMotiveSettingRepositoryPort.
      def initialize(subscriptions:, deliveries:, approvals:, settings:, clock:)
        @subscriptions = subscriptions
        @deliveries = deliveries
        @approvals = approvals
        @settings = settings
        @clock = clock
      end

      # → success({ subscriptions: n, deliveries: m, approvals: a, setting_changes: c })
      def call
        now = @clock.now
        Shared::Result.success(subscriptions: @subscriptions.delete_stale(before: now - SUBSCRIPTION_TTL),
                               deliveries: @deliveries.purge_before(before: now - DELIVERY_TTL),
                               approvals: @approvals.purge_before(before: now - DELIVERY_TTL),
                               setting_changes: @settings.purge_changes_before(before: now - DELIVERY_TTL))
      end
    end
  end
end
