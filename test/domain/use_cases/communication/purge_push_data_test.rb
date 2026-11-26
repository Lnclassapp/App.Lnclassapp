require "test_helper"

# ADR-0146 §4.1 : abonnements sans envoi réussi depuis 60 jours, envois de plus de 90 jours ;
# ADR envois de notifications §4.1 : validations et historique des réglages de plus de 90 jours.
module UseCases
  module Communication
    class PurgePushDataTest < ActiveSupport::TestCase
      class Subscriptions
        attr_reader :before

        def delete_stale(before:) = (@before = before; 2)
      end

      class Deliveries
        attr_reader :before

        def purge_before(before:) = (@before = before; 5)
      end

      class Approvals
        attr_reader :before

        def purge_before(before:) = (@before = before; 3)
      end

      class Settings
        attr_reader :before

        def purge_changes_before(before:) = (@before = before; 4)
      end

      test "purge les abonnements de plus de 60 jours les envois, les validations et l'historique des réglages de plus de 90 jours, et compte" do
        now = Time.utc(2026, 11, 18, 5)
        subscriptions = Subscriptions.new
        deliveries = Deliveries.new
        approvals = Approvals.new
        settings = Settings.new

        result = PurgePushData.new(subscriptions:, deliveries:, approvals:, settings:, clock: Struct.new(:now).new(now)).call

        assert result.success?
        assert_equal({ subscriptions: 2, deliveries: 5, approvals: 3, setting_changes: 4 }, result.value)
        assert_equal now - 60.days, subscriptions.before
        assert_equal now - 90.days, deliveries.before
        assert_equal now - 90.days, approvals.before
        assert_equal now - 90.days, settings.before
      end
    end
  end
end
